require 'active_support/security_utils'
require 'active_support/core_ext/string/inflections'
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

    def login(user, password, remember_me)
      user = user.downcase if user.is_a?(String)
      # see Users::get_info
      remember_me = true unless !!remember_me == remember_me

      matches, confirmed = Passwords.matches?(user, password)

      raise NotConfirmedError, 'Account is not confirmed! Please check your email or register under the same username to resend the email.' unless confirmed
      raise Passwords::MismatchError, 'Invalid username / password!' unless matches

      DB[:users].update_one({user: user}, '$currentDate' => {lastLogin: true})

      return JWT.generate(user, remember_me)

      nil
    end

    def register(user)
      raise TypeError, 'invalid user hash' unless user.is_a?(Hash)

      user['user'] = user['user'].downcase if user['user'].is_a?(String)
      %w(firstName lastName).each do |key|
        raise TypeError, "invalid #{key.underscore.tr('_', ' ')}" unless user[key].is_a?(String)
      end
      user['gradYear'] = nil unless user['gradYear'].is_a?(Integer)

      # Users::get *should* raise an error if the user is not found
      # if there isn't an error, that means the user was found, so check for confirmation
      begin
        user_doc = Users.get(user['user'])
      rescue Users::UserNotFoundError
      else
        raise AlreadyRegistered, "An account is already registered under the email #{user['user']}@micds.org!" if user_doc['confirmed']
      end

      confirmation_hash = SecureRandom.hex(16)

      new_user = {
        'user' => user['user'],
        'password' => BCrypt::Password.create(user['password']),
        'firstName' => user['firstName'],
        'lastName' => user['lastName'],
        'gradYear' => user['gradYear'],
        'confirmed' => false,
        'registered' => Time.now,
        'confirmationHash' => confirmation_hash,
        'scopes' => []
      }

      DB[:users].update_one(
        {user: new_user['user']},
        new_user,
        upsert: true
      )

      Mail.send_erb(
        new_user['user'] + '@micds.org',
        'Confirm your Account',
        File.expand_path('../../erb/register.erb', __FILE__),
        {
          first_name: new_user['firstName'],
          last_name: new_user['lastName'],
          confirm_link: "https://mymicds.net/confirm/#{new_user['user']}/#{confirmation_hash}"
        }
      )

      Admins.send_email(
        subject: "#{new_user['user']} just created a 2.0 account!",
        html: "#{new_user['firstName']} #{new_user['lastName']} (#{new_user['gradYear']}) just created an account with the username #{new_user['user']}"
      )

      nil
    end

    def confirm(user, confirmation_hash)
      raise TypeError, 'invalid confirmation hash' unless confirmation_hash.is_a?(String)

      if ActiveSupport::SecurityUtils.secure_compare(confirmation_hash, Users.get(user)['confirmationHash'])
        DB[:users].update_one(
          {user: user},
          '$set' => {confirmed: true}
        )
      else
        raise Passwords::MismatchError, 'Confirmation hashes do not match!'
      end

      nil
    end
  end
end
