require_relative '../lib/auth'

class MyMICDS
  module AuthRoutes
    def self.registered(app)
      app.namespace '/auth' do
        post '/login' do
          result = {}

          if request.env[:user]
            result[:error] = nil
            result[:jwt] = nil
            result[:message] = 'You\'re already logged in, silly!'
            result[:success] = false
            status 400
          else
            remember_me = !params['remember'].nil?

            begin
              result[:error] = nil
              result[:jwt] = Auth.login(params['user'], params['password'], remember_me)
              result[:message] = 'Success!'
              result[:success] = true
              status 200
            rescue Auth::Error, Passwords::Error => err
              result[:error] = nil
              result[:jwt] = nil
              result[:message] = err.message
              result[:success] = false
              status 401
            rescue => err
              result[:error] = err.message
              result[:jwt] = nil
              result[:message] = nil
              result[:success] = nil
              status 403
            end
          end

          json(result)
        end
      end
    end
  end
end