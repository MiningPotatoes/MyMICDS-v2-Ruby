require 'json'
require 'mongo'
require 'rack/parser'
require 'sinatra/base'
require 'sinatra/json'
require 'sinatra/namespace'
require 'yaml'

# because Mongo messages get annoying
Mongo::Logger.logger.level = ::Logger::FATAL

# to keep compatibility with JS API
# otherwise, it would return `{"$oid" => to_s}`
module BSON
  class ObjectId
    def as_json(*args)
      to_s
    end
  end
end

class MyMICDS < Sinatra::Base
  CONFIG = YAML.load_file(File.expand_path('../config.yaml', __FILE__))
  DB = Mongo::Client.new(CONFIG['mongodb']['uri'])

  configure do
    disable :protection, :raise_errors, :show_exceptions

    require_relative 'lib/jwt'
    use JWT::Middleware

    use Rack::Parser
    register Sinatra::Namespace

    %w(
      alias
      auth
      classes
      lunch
      users
    ).each do |section|
      require_relative "routes/#{section}"
      register const_get(section.capitalize + 'Routes')
    end
  end

  error Mongo::Error do
    status 500
    json({error: 'There was an error accessing the database!'})
  end

  not_found do
    json({error: 'Endpoint not found!'})
  end

  # all errors except Mongo::Error should be handled in the routes
  # and information and status codes should be returned accordingly
end
