require_relative '../lib/lunch'

class MyMICDS
  module LunchRoutes
    def self.registered(app)
      app.get '/lunch' do
        current = Time.now
        result = {}

        date_fields = %w(year month day)

        date_vals = date_fields.each_with_object({}) do |key, memo|
          memo[key] = params[key] || current.send(key)
        end

        begin
          result[:error] = nil
          result[:lunch] = Lunch.get(Time.new(*date_vals.values_at(*date_fields)))
        rescue Mongo::Error
          raise
        rescue => err
          result[:error] = err.message
          result[:lunch] = nil
        end

        json(result)
      end
    end
  end
end
