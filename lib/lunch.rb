require 'active_support/core_ext/time/calculations'
require 'nokogiri'
require 'rest-client'
require 'time'

require_relative 'admins'

class MyMICDS
  module Lunch
    module_function

    def get_lunch(time = Time.now)
      res = RestClient.post(
        'http://myschooldining.com/MICDS/calendarWeek',
        current_day: time.beginning_of_week(:wednesday).iso8601
      )

      unless res.code == 200
        Admins.send_email(
          subject: 'Error Notification - Lunch Retrieval',
          html: "There was a problem with the lunch URL.<br>Status code: #{res.code}"
        )

        return
      end

      json = {}

      Nokogiri::HTML(
        # clean up the HTML to keep the parser from getting confused
        res.body.gsub(/(<<|>>)/, {
          '<<' => '&lt;&lt',
          '>>' => '&gt;&gt;'
        })
      ).css('table#table_calendar_week td').each do |day|
        date_str = Time.strptime(day.attr('this_date'), '%D').strftime('%F')

        %w(Lower Middle Upper).map {|s| s + ' School'}.each do |school|
          school_lunch = day.css(%(div[location="#{school}"]))

          unless school_lunch.empty?
            # we put this outside the category loop so it doesn't constantly get re-eval'd
            lunch_title = school_lunch.css('span.period-value').text.strip

            school_lunch.css('div.category-week').each do |category|
              category_title = category.css('span.category-value').text.strip
              food = category.css('div.item-week').map {|i| i.text.strip}

              # process the school names into keys
              # these are string keys instead of symbols because
              # 1. it'd look bad if everything dynamic had a `.to_sym` on it
              # 2. the hash is meant to be converted straight to a JSON string, not to be processed any more
              # 3. the translation from JS was easier without conversion
              filter = lambda {|s| s.gsub(/\s+/, '').downcase}

              # add everything to JSON
              json[date_str] ||= {}
              json[date_str][filter.call(school)] ||= {}

              json[date_str][filter.call(school)]['title'] = lunch_title
              json[date_str][filter.call(school)]['categories'] ||= {}
              json[date_str][filter.call(school)]['categories'][category_title] ||= []

              json[date_str][filter.call(school)]['categories'][category_title].concat(food)
            end
          end
        end
      end

      json
    end

    class << self
      alias get get_lunch
    end
  end
end
