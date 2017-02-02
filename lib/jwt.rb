require 'jwt'
require 'json'
require 'yaml'

class MyMICDS
	class JWTMiddleware
		def initialize(app)
			@app = app
		end

		def call(env)
			# we have our own way of handling if the user is authorized or not
			# so it's okay if there's no JWT header
			# we'll just have to skip to the end
			if !env['HTTP_AUTHORIZATION'].nil?
				bearer, token = env['HTTP_AUTHORIZATION'].split(' ')
				raise ArgumentError, 'invalid format (must be "Bearer [token]")' unless bearer == 'Bearer'

				config = YAML.load_file(File.expand_path('../../config.yml', __FILE__))

				opts = {
					aud: config['hosted_on'],
					iss: config['hosted_on'],
					sub: 'MyMICDS API',
				}

				%w(aud iat iss sub).each {|type| opts["verify_#{type}".to_sym] = true}

				payload, header = ::JWT.decode(token, config['jwt']['secret'], true, opts)

				env[:scopes] = payload['scopes']
				env[:user] = payload['user']
			end

			@app.call(env)
		rescue ArgumentError => err
			handle_err(err, 400)
		rescue ::JWT::ExpiredSignature,
			   ::JWT::InvalidAudError,
			   ::JWT::InvalidIatError,
			   ::JWT::InvalidIssuerError => err
			handle_err(err, 403)
		rescue ::JWT::DecodeError => err # because most of the above are subclasses of DecodeError, this has to come last
			handle_err(err, 401)
		end

		def handle_err(err, code)
			[code, {'Content-Type' => 'application/json'}, [{error: "#{err.class}: #{err.message}"}.to_json]]
		end
	end

	module JWT
		module_function

		# TODO
	end
end