require 'active_support/security_utils'
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

    Error = Class.new(StandardError)

    MismatchError = Class.new(Error)
    EmailNotSentError = Class.new(Error)

    module_function

    def matches?(user, password)
      raise TypeError, 'invalid password' unless password.is_a?(String)

      user_doc = Users.get(user)
      return BCrypt::Password.new(user_doc['password']) == password, user_doc['confirmed']
    end

    def change(user, old_pass, new_pass)
      # even though #matches? already has a password type check,
      # the message isn't informative enough
      raise TypeError, 'invalid old password' unless old_pass.is_a?(String)
      raise ArgumentError, 'password blacklisted' if BLACKLIST.include?(old_pass)
      raise TypeError, 'invalid new password' unless new_pass.is_a?(String)

      matches, confirmed = matches?(user, old_pass)
      raise MismatchError, 'passwords do not match' unless matches

      DB[:users].update_one(
        {user: user},
        '$set' => {password: BCrypt::Password.create(new_pass)},
        '$currentDate' => {lastPasswordChange: true}
      )

      nil
    end

    def send_reset_email(user)
      user_doc = Users.get(user)

      reset_hash = SecureRandom.hex(16)

      DB[:users].update_one(
        {user: user},
        {'$set' => {passwordChangeHash: Digest::SHA256.hexdigest(reset_hash)}},
        upsert: true
      )

      Mail.send_erb(
        user + '@micds.org',
        'Change your password',
        File.expand_path('../erb/password.erb', __dir__),
        {
          first_name: user_doc['firstName'],
          last_name: user_doc['lastName'],
          password_link: "https://mymicds.net/reset-password/#{user_doc['user']}/#{reset_hash}"
        }
      )

      nil
    end

    def reset(user, password, reset_hash)
      raise TypeError, 'invalid password' unless password.is_a?(String)
      raise ArgumentError, 'password blacklisted' if BLACKLIST.include?(password)
      raise TypeError, 'invalid reset hash' unless reset_hash.is_a?(String)

      db_hash = Users.get(user)['passwordChangeHash']
      hash_check = Digest::SHA256.hexdigest(reset_hash)

      raise EmailNotSentError, 'password reset email never sent' if !db_hash.is_a?(String) || db_hash.nil?
      raise MismatchError, 'password reset hashes do not match' unless ActiveSupport::SecurityUtils.secure_compare(db_hash, hash_check)

      DB[:users].update_one(
        {user: user},
        '$set' => {
          password: BCrypt::Password.create(password),
          passwordChangeHash: nil
        },
        '$currentDate' => {lastPasswordChange: true}
      )

      nil
    end
  end
end
