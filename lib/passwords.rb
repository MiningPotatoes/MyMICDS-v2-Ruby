require 'bcrypt'
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
      return unless block_given?
      raise TypeError, 'invalid password' unless password.is_a?(String)

      user_doc = Users.get(db, user)
      return BCrypt::Password.new(user_doc['password']) == password, user_doc['confirmed']
    end

    def change(db, user, old_pass, new_pass)
      raise TypeError, 'invalid old password' unless old_pass.is_a?(String)
      raise ArgumentError, 'password blacklisted' if BLACKLIST.include?(old_pass)
      raise TypeError, 'invalid new password' unless new_pass.is_a?(String)

      hashed = BCrypt::Password.create(new_pass)
      raise MismatchError, 'passwords do not match' unless matches?(db, user, old_pass)[0]

      db[:users].update_one(
        {user: user},
        '$set' => {password: hashed},
        '$currentDate' => {lastPasswordChange: true}
      )

      nil
    end
  end
end