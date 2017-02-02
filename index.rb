require 'json'
require 'mongo'
require 'rack/parser'
require 'sinatra/base'
require 'sinatra/json'
require 'sinatra/namespace'
require 'yaml'

# because Mongo messages get annoying
Mongo::Logger.logger.level = ::Logger::FATAL

class MyMICDS < Sinatra::Base
  CONFIG = YAML.load_file(File.expand_path('../config.yml', __FILE__))

  configure do
    # this can be loaded in multiple files, since the libs sometimes need it
    set :db, Mongo::Client.new(CONFIG['mongodb']['uri'])
    disable :protection

    require_relative 'lib/jwt'
    use JWT::Middleware, db: settings.db

    use Rack::Parser

    %w(
      users
    ).each do |file|
      require_relative "routes/#{file}"
    end
    register Sinatra::Namespace
    register Routes
  end

  # all errors should be handled in the routes
  # and information should be returned accordingly
end
