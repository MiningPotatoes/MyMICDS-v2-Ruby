require 'active_support/core_ext/string/inflections'

require_relative '../lib/auth'

class MyMICDS
  module AuthRoutes
    def self.registered(app)
      app.namespace '/auth' do
        post '/login' do
          result = {}

          unless request.env[:jwt].empty?
            result[:error] = nil
            result[:jwt] = nil
            result[:message] = 'You\'re already logged in, silly!'
            result[:success] = false
            status 400
          else
            remember_me = !params['remember']

            begin
              result[:error] = nil
              result[:jwt] = Auth.login(*params.values_at('user', 'password'), remember_me)
              result[:message] = 'Success!'
              result[:success] = true
            rescue Mongo::Error, Mongo::Auth::Unauthorized
              raise
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

        post '/logout' do
          result = {}

          begin
            JWT.revoke(request.env[:jwt], request.env['HTTP_AUTHORIZATION']&.slice(7..-1))
            result[:error] = nil
          rescue Mongo::Error, Mongo::Auth::Unauthorized
            raise
          rescue => err
            result[:error] = err.message
            status 400
          end

          json(result)
        end

        post '/register' do
          result = {}
          user = {}

          %w(user password firstName lastName gradYear).each do |key|
            user[key.underscore.to_sym] = (key == 'gradYear' ? params[key].to_i : params[key])
          end
          user[:grad_year] = nil if params['teacher']

          begin
            Auth.register(user)
            result[:error] = nil
            status 201
          rescue MongoError
            raise
          rescue => err
            result[:error] = err.message
            status 400
          end

          json(result)
        end

        post '/confirm' do
          result = {}

          begin
            Auth.confirm(*params.values_at('user', 'hash'))
          rescue Mongo::Error, Mongo::Auth::Unauthorized
            raise
          rescue => err
            result[:error] = err.message
            status 400
          end

          json(result)
        end
      end

      app.namespace '/password' do
        patch '' do
          result = {}

          begin
            Passwords.change(request.env[:jwt]['user'], *params.values_at('oldPassword', 'newPassword'))
            result[:error] = nil
          rescue Mongo::Error, Mongo::Auth::Unauthorized
            raise
          rescue => err
            result[:error] = err.message
            status 400
          end
          json(result)
        end

        put '' do
          result = {}

          if request.env[:jwt]['user']
            result[:error] = 'You\'re already logged in, silly!'
          else
            begin
              Passwords.reset(*params.values_at('user', 'password', 'hash'))
              result[:error] = nil
              status 201
            rescue Mongo::Error, Mongo::Auth::Unauthorized
              raise
            rescue => err
              result[:error] = err.message
              status 400
            end
          end

          json(result)
        end

        post '/forgot' do
          result = {}

          if request.env[:jwt]['user']
            result[:error] = 'You\'re already logged in, silly!'
          else
            begin
              Passwords.send_reset_email(params['user'])
              result[:error] = nil
            rescue Mongo::Error, Mongo::Auth::Unauthorized
              raise
            rescue => err
              result[:error] = err.message
              status 400
            end
          end

          json(result)
        end
      end
    end
  end
end
