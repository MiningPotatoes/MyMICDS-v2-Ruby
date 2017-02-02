require 'active_support/core_ext/string/inflections'
require 'time'
require_relative '../lib/users'

class MyMICDS
	module Routes
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
						Users.get_info(settings.db, request.env[:user], true) do |info|
							result[:error] = nil
							result[:user_info] = info
						end
					rescue => err
						result[:error] = err.message
						result[:user_info] = nil
					end

					json(result)
				end

				put '/info' do
					info = {}
					result = {}
					
					# programmatically assign these values because it's ugly when done manually
					%w(firstName lastName).each do |key|
						info[key.underscore.to_sym] = params[key] if params[key].is_a?(String) && !params[key].empty?
					end
					info[:grad_year] = params['teacher'] ? nil : params['gradYear'].to_i

					begin
						Users.change_info(settings.db, request.env[:user], info)
						result[:error] = nil
					rescue => err
						result[:error] = err.message
					end

					json(result)
				end
			end
		end
	end
end