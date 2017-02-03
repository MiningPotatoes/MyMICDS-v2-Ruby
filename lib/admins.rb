require_relative 'mail'

class MyMICDS
  module Admins
    module_function

    def get_admins
      DB[:users].find(scopes: {'$in' => ['admin']}).to_a
    end

    def send_email(message)
      Mail.send(get_admins.map {|admin| admin[:user] + '@micds.org'}, message)
    end

    class << self
      alias get get_admins
    end
  end
end