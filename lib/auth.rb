require 'active_support/security_utils'
require 'bcrypt'
require 'securerandom'

require_relative 'admins'
require_relative 'jwt'
require_relative 'mail'
require_relative 'passwords'
require_relative 'users'

class MyMICDS
  module Auth
    Error = Class.new(StandardError)

    AlreadyRegistered = Class.new(Error)
    NotConfirmedError = Class.new(Error)

    module_function

    def login(db, user, password, remember_me)
      user = user.downcase if user.is_a?(String)
      # see Users::get_info
      remember_me = true unless !!remember_me == remember_me

      matches, confirmed = Passwords.matches?(db, user, password)

      raise NotConfirmedError, 'Account is not confirmed! Please check your email or register under the same username to resend the email.' unless confirmed
      raise Passwords::MismatchError, 'Invalid username / password!' unless matches

      db[:users].update_one({user: user}, '$currentDate' => {lastLogin: true})

      return JWT.generate(db, user, remember_me)
    end

    def register(db, user)
      raise TypeError, 'invalid user hash' unless user.is_a?(Hash)

      user[:user] = user[:user].downcase if user[:user].is_a?(String)
      %i(first_name last_name).each do |key|
        raise TypeError, "invalid #{key.to_s.tr('_', ' ')}" unless user[key].is_a?(String)
      end
      user[:grad_year] = nil unless user[:grad_year].is_a?(Integer)

      # Users::get *should* raise an error if the user is not found
      # if there isn't an error, that means the user was found, so check for confirmation
      begin
        user_doc = Users.get(db, user[:user])
      rescue Users::UserNotFoundError
      else
        raise AlreadyRegistered, "An account is already registered under the email #{user[:user]}@micds.org!" if user_doc[:confirmed]
      end

      confirmation_hash = SecureRandom.hex(16)

      new_user = {
        user: user[:user],
        password: BCrypt::Password.create(user[:password]),
        firstName: user[:first_name],
        lastName: user[:last_name],
        gradYear: user[:grad_year],
        confirmed: false,
        registered: Time.now,
        confirmationHash: confirmation_hash,
        scopes: []
      }

      db[:users].update_one(
        {user: new_user[:user]},
        new_user,
        {upsert: true}
      )

      Mail.send_erb(
        new_user[:user] + '@micds.org',
        'Confirm your Account',
        File.expand_path('../../erb/register.erb', __FILE__),
        {
          first_name: new_user[:firstName],
          last_name: new_user[:lastName],
          confirm_link: "https://mymicds.net/confirm/#{new_user[:user]}/#{confirmation_hash}"
        }
      )

      Admins.send_email(
        db,
        subject: "#{new_user[:user]} just created a 2.0 account!",
        html: "#{new_user[:firstName]} #{new_user[:lastName]} (#{new_user[:gradYear]}) just created an account with the username #{new_user[:user]}"
      )
    end

    def confirm(db, user, confirmation_hash)
      raise TypeError, 'invalid confirmation hash' unless confirmation_hash.is_a?(String)

      user_doc = Users.get(db, user)

      if ActiveSupport::SecurityUtils.secure_compare(confirmation_hash, user_doc[:confirmation_hash])
        db[:users].update_one(
          {user: user},
          '$set' => {confirmed: true}
        )
      else
        raise Passwords::MismatchError, 'Confirmation hashes do not match!'
      end
    end
  end
end