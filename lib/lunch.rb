require 'nokogiri'
require 'rest-client'
require 'time'

class MyMICDS
  module Lunch
    module_function

    def get_lunch(date)
      # TODO
    end

    class << self
      alias get get_lunch
    end
  end
end