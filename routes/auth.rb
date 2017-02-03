require 'active_support/core_ext/string/inflections'

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
            remember_me = !params['remember']

            begin
              result[:error] = nil
              result[:jwt] = Auth.login(params['user'], params['password'], remember_me)
              result[:message] = 'Success!'
              result[:success] = true
            rescue Mongo::Error
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
          rescue Mongo::Error
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
            Auth.confirm(params['user'], params['hash'])
          rescue Mongo::Error
            raise
          rescue => err
            result[:error] = err.message
            status 400
          end

          json(result)
        end
      end
    end
  end
end