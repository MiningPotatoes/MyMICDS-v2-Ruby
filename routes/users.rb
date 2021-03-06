require 'time'

require_relative '../lib/users'

class MyMICDS
  module UsersRoutes
    def self.registered(app)
      app.namespace '/user' do
        get '/grad-year-to-grade' do
          json({grade: Users.grad_year_to_grade(params['year'])})
        end

        get '/grade-to-grad-year' do
          json({grade: Users.grade_to_grad_year(params['grade'])})
        end

        get '/school-ends' do
          json({ends: Users.school_ends.iso8601})
        end

        get '/grade-range' do
          grad_years = -1.upto(12).map {|i| Users.grade_to_grad_year(i)}
          json({gradYears: grad_years.reverse}) # return the most recent ones first
        end

        get '/info' do
          result = {}

          begin
            result[:error] = nil
            result[:user] = Users.get_info(request.env[:jwt]['user'], true)
          rescue Mongo::Error, Mongo::Auth::Unauthorized
            raise
          rescue => err
            result[:error] = err.message
            result[:user] = nil
            status 400
          end

          json(result)
        end

        put '/info' do
          info = {}
          result = {}
          
          # programmatically assign these values because it's ugly when done manually
          %w(firstName lastName).each do |key|
            info[key] = params[key] if params[key].is_a?(String) && !params[key].empty?
          end
          info['gradYear'] = params['teacher'] ? nil : params['gradYear'].to_i

          begin
            Users.change_info(request.env[:jwt]['user'], info)
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
      end
    end
  end
end
