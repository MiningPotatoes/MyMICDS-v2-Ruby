require_relative 'mail'

class MyMICDS
  module Admins
    module_function

    def get_admins(db)
      raise TypeError, 'invalid database connection' unless db.is_a?(Mongo::Client)

      db[:users].find(scopes: {'$in' => ['admin']}).to_a
    end

    def send_email(db, message)
      Mail.send(get_admins(db).map {|admin| admin[:user] + '@micds.org'}, message)
    end

    class << self
      alias get get_admins
    end
  end
end