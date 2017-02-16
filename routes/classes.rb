require_relative '../lib/classes'

class MyMICDS
  module ClassesRoutes
    def self.registered(app)
      app.post '/classes' do
        result = {}
        schedule_class = {
          '_id' => params[:id]
        }

        Classes::FIELDS.each {|f| schedule_class[f] = params[f]}
        Teachers::FIELDS.each {|f| schedule_class['teacher'][f] = params['teacher' + f.capitalize]}

        begin
          Classes.upsert(request.env[:jwt]['user'], schedule_class)
          result[:error] = nil
          status 201
        rescue Mongo::Error, Mongo::Auth::Unauthorized
          raise
        rescue => err
          result[:error] = err.message
          status 400
        end

        result[:id] = schedule_class['_id']

        json(result)
      end

      app.get '/classes' do
        result = {}

        begin
          result[:classes] = Classes.get(request.env[:jwt]['user'])
          result[:error] = nil
        rescue Mongo::Error, Mongo::Auth::Unauthorized
          raise
        rescue => err
          result[:classes] = nil
          result[:error] = err.message
          status 400
        end

        json(result)
      end

      app.delete '/classes' do
        result = {}

        begin
          Classes.delete(request.env[:jwt]['user'], params[:id])
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