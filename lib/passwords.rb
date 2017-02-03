require 'bcrypt'
require 'digest'
require 'securerandom'
require_relative 'mail'
require_relative 'users'

class MyMICDS
  module Passwords
    BLACKLIST = [
      '', # empty string
      'Michael is not a nerd' # Michael i will fight you
    ]

    MismatchError = Class.new(StandardError)

    module_function

    def matches?(db, user, password)
      raise TypeError, 'invalid password' unless password.is_a?(String)

      user_doc = Users.get(db, user)
      return BCrypt::Password.new(user_doc[:password]) == password, user_doc[:confirmed]
    end

    def change(db, user, old_pass, new_pass)
      raise TypeError, 'invalid old password' unless old_pass.is_a?(String)
      raise ArgumentError, 'password blacklisted' if BLACKLIST.include?(old_pass)
      raise TypeError, 'invalid new password' unless new_pass.is_a?(String)

      hashed = BCrypt::Password.create(new_pass)

      matches, confirmed = matches?(db, user, old_pass)
      raise MismatchError, 'passwords do not match' unless matches

      db[:users].update_one(
        {user: user},
        '$set' => {password: hashed},
        '$currentDate' => {lastPasswordChange: true}
      )

      nil
    end

    def send_reset_email(db, user)
      user_doc = Users.get(db, user)

      reset_hash = SecureRandom.hex(16)
      reset_hashed_hash = Digest::SHA256.hexdigest(reset_hash)

      db[:users].update_one(
        {user: user_doc[:user]},
        {'$set' => {passwordChangeHash: reset_hashed_hash}},
        {upsert: true}
      )

      Mail.send_erb(
        user_doc[:user] + '@micds.org',
        'Change your password',
        File.expand_path('../../erb/password.erb', __FILE__),
        {
          first_name: user_doc[:first_name],
          last_name: user_doc[:last_name],
          password_link: "https://mymicds.net/reset-password/#{user_doc[:user]}/#{reset_hash}"
        }
      )

      nil
    end

    def reset(db, user, password, hash)
      # TODO
    end
  end
end