require_relative '../lib/aliases'

class MyMICDS
  module AliasRoutes
    def self.registered(app)
      app.post '/alias' do
        result = {}

        begin
          Aliases.add(request.env[:jwt]['user'], *params.values_at('type', 'classString', 'classId'))
          result[:error] = nil
          status 201
        rescue Mongo::Error, Mongo::Auth::Unauthorized
          raise
        rescue => err
          result[:error] = err.message
          status 400
        end

        json(result)
      end

      app.get '/alias' do
        result = {}

        begin
          result[:aliases] = Aliases.list(request.env[:jwt]['user'])
          result[:error] = nil
        rescue Mongo::Error, Mongo::Auth::Unauthorized
          raise
        rescue => err
          result[:aliases] = nil
          result[:error] = err.message
          status 400
        end

        json(result)
      end

      app.delete '/alias' do
        result = {}

        begin
          Aliases.delete(request.env[:jwt]['user'], *params.values_at('type', 'id'))
          result[:error] = nil
        rescue Mongo::Error, Mongo::Auth::Unauthorized
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