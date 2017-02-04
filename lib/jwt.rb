require 'active_support/core_ext/numeric/time'
require 'jwt'
require 'json'
require 'yaml'

require_relative 'users'

module JWT
  TokenRevoked = Class.new(DecodeError)
end

class MyMICDS
  module JWT
    class Middleware
      def initialize(app)
        @app = app
      end

      def call(env)
        # we have our own way of handling if the user is authorized or not
        # so it's okay if there's no JWT header
        # we'll just have to skip to the end
        unless env['HTTP_AUTHORIZATION'].nil?
          bearer, token = env['HTTP_AUTHORIZATION'].split(' ')
          raise ArgumentError, 'invalid format (must be "Bearer [token]")' unless bearer == 'Bearer'

          opts = {
            algorithm: 'HS256',
            aud: CONFIG['hosted_on'],
            iss: CONFIG['hosted_on'],
            leeway: 30,
            sub: 'MyMICDS API'
          }

          %w(aud iat iss sub).each {|type| opts["verify_#{type}".to_sym] = true}

          payload, header = ::JWT.decode(
            token,
            CONFIG['jwt']['secret'],
            true,
            opts
          )
          
          raise ::JWT::TokenRevoked, 'token has been revoked' if JWT.revoked?(payload, token)

          env[:jwt] = payload
        else
          env[:jwt] = {}
        end

        @app.call(env)
      rescue ArgumentError => err
        handle_err(err, 400)
      rescue ::JWT::DecodeError => err
        handle_err(err, 401)
      end

      def handle_err(err, code)
        [code, {'Content-Type' => 'application/json'}, [{error: "#{err.class}: #{err.message}"}.to_json]]
      end
    end

    module_function

    def blacklisted?(jwt)
      raise TypeError, 'invalid JWT' unless jwt.is_a?(String)

      !DB[:JWTBlacklist].find(jwt: jwt).to_a.empty?
    end

    def generate(user, remember_me)
      user_doc = Users.get(user)

      # default scopes
      scopes = {pleb: true}

      if user_doc['scopes'].is_a?(Array)
        user_doc['scopes'].each {|scope| scopes[scope] = true}
      end

      ::JWT.encode(
        {
          # payload
          user: user,
          scopes: scopes,
          # JWT metadata
          aud: CONFIG['hosted_on'],
          exp: Time.now.to_i + (remember_me ? 30.days : 12.hours),
          iat: Time.now.to_i,
          iss: CONFIG['hosted_on'],
          sub: 'MyMICDS API'
        },
        CONFIG['jwt']['secret'],
        'HS256'
      )
    end

    def revoke(payload, jwt)
      raise TypeError, 'invalid payload' unless payload.is_a?(Hash)
      raise TypeError, 'invalid JWT' unless jwt.is_a?(String)

      DB[:JWTBlacklist].insert_one({
        user: payload['user'],
        jwt: jwt,
        expires: Time.at(payload['exp']),
        revoked: Time.now
      })

      nil
    end

    def revoked?(payload, jwt)      
      return unless payload.is_a?(Hash)

      DB[:users].update_one({user: payload['user']}, '$currentDate' => {lastVisited: true})

      blacklisted?(jwt)
    end
  end
end