require 'mail'
require 'uri'

module URI
  class SMTP < Generic
    DEFAULT_PORT = 25
  end
  class SMTPS < Generic
    DEFAULT_PORT = 587
  end
  @@schemes['SMTP'] = SMTP
  @@schemes['SMTPS'] = SMTPS
end

class MyMICDS
  module Mail
    module_function

    def send(users, message = {})
      raise TypeError, 'invalid message hash' unless message.is_a?(Hash)
      raise TypeError, 'invalid mail subject' unless message[:subject].is_a?(String)
      raise TypeError, 'invalid mail HTML' unless message[:html].is_a?(String)
      raise TypeError, 'invalid user(s)' unless users.is_a?(String) || users.is_a?(Array)

      mailer = URI(CONFIG['email']['uri'])

      Mail.defaults do
        delivery_method :smtp, {
          address: mailer.host,
          authentication: 'plain',
          port: mailer.port,
          user_name: URI.unescape(mailer.user),
          password: mailer.password
        }
      end

      user_str = users.is_a?(Array) ? users.join(',') : users

      Mail.deliver do
        from "#{CONFIG['email']['from_name']} <#{CONFIG['email']['from_email']}>"
        to user_str
        subject message[:subject]
        body message[:html]
      end
    end
  end
end