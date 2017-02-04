require 'active_support/core_ext/time/calculations'
require 'nokogiri'
require 'rest-client'
require 'time'

class MyMICDS
  module Lunch
    module_function

    def get_lunch(time = Time.now)
      res = RestClient.post(
       'http://myschooldining.com/MICDS/calendarWeek',
       current_day: time.beginning_of_week(:wednesday).iso8601
      )

      unless res.code == 200
        # send admin email
      end
    end

    class << self
      alias get get_lunch
    end
  end
end