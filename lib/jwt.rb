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
      def initialize(app, db: )
        @app = app
        @db = db
      end

      def call(env)
        # we have our own way of handling if the user is authorized or not
        # so it's okay if there's no JWT header
        # we'll just have to skip to the end
        if !env['HTTP_AUTHORIZATION'].nil?
          bearer, token = env['HTTP_AUTHORIZATION'].split(' ')
          raise ArgumentError, 'invalid format (must be "Bearer [token]")' unless bearer == 'Bearer'

          opts = {
            algorithm: 'HS256',
            aud: MyMICDS::CONFIG['hosted_on'],
            iss: MyMICDS::CONFIG['hosted_on'],
            leeway: 30,
            sub: 'MyMICDS API'
          }

          %w(aud iat iss sub).each {|type| opts["verify_#{type}".to_sym] = true}

          payload, header = ::JWT.decode(
            token,
            MyMICDS::CONFIG['jwt']['secret'],
            true,
            opts
          )

          JWT.revoked?(@db, payload, token) do |revoked|
            raise ::JWT::TokenRevoked, 'token has been revoked' if revoked
          end

          env[:scopes] = payload['scopes']
          env[:user] = payload['user']
        end

        @app.call(env)
      rescue ArgumentError => err
        handle_err(err, 400)
      rescue ::JWT::ExpiredSignature,
           ::JWT::InvalidAudError,
           ::JWT::InvalidIatError,
           ::JWT::InvalidIssuerError,
           ::JWT::TokenRevoked => err
        handle_err(err, 403)
      rescue ::JWT::DecodeError => err # because most of the above are subclasses of DecodeError, this has to come last
        handle_err(err, 401)
      end

      def handle_err(err, code)
        [code, {'Content-Type' => 'application/json'}, [{error: "#{err.class}: #{err.message}"}.to_json]]
      end
    end

    module_function

    def blacklisted?(db, jwt)
      return unless block_given?
      raise TypeError, 'invalid database connection' unless db.is_a?(Mongo::Client)
      raise TypeError, 'invalid JWT' unless jwt.is_a?(String)

      # this is in a block since it's a database query
      # and so we can check for errors before returning
      yield !db[:JWTBlacklist].find(jwt: jwt).to_a.empty?
    end

    def generate(db, user, remember_me)
      return unless block_given?
      raise TypeError, 'invalid database connection' unless db.is_a?(Mongo::Client)

      Users.get(db, user) do |user_doc|
        # default scopes
        scopes = {pleb: true}

        if user_doc['scopes'].is_a?(Array)
          user_doc['scopes'].each {|scope| scopes[scope] = true}
        end

        yield ::JWT.encode(
          {
            user: user,
            scopes: scopes
          },
          MyMICDS::CONFIG['jwt']['secret'],
          {
            aud: MyMICDS::CONFIG['hosted_on'],
            exp: Time.now.to_i + (remember_me ? 30.days : 12.hours),
            iat: Time.now.to_i,
            iss: MyMICDS::CONFIG['hosted_on'],
            sub: 'MyMICDS API'
          },
          'HS256'
        )
      end
    end

    def revoke(db, payload, jwt)
      raise TypeError, 'invalid database connection' unless db.is_a?(Mongo::Client)
      raise TypeError, 'invalid payload' unless payload.is_a?(Hash)
      raise TypeError, 'invalid JWT' unless jwt.is_a?(String)

      db[:JWTBlacklist].insert_one({
        user: payload['user'],
        jwt: jwt,
        expires: Time.at(payload['exp']),
        revoked: Time.now
      })

      # see Users::change_info
      nil
    end

    def revoked?(db, payload, jwt)
      return unless payload.is_a?(Hash) && block_given?

      blacklisted?(db, jwt) do |blacklisted|
        db[:users].update_one({user: payload['user']}, '$currentDate' => {lastVisited: true})

        yield blacklisted
      end
    end
  end
end