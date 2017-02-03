require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/numeric/time'
require 'active_support/core_ext/time'

class MyMICDS
  module Users
    UserNotFoundError = Class.new(StandardError)

    module_function

    def get_user(user)
      raise TypeError, 'invalid username' unless user.is_a?(String)

      userdata = DB[:users]
      user_docs = userdata.find(user: user).to_a

      raise UserNotFoundError, "user #{user} not found in database" if user_docs.empty?

      user_docs[0].transform_keys {|k| k.underscore.to_sym}
    end

    def get_info(user, private_info)
      # since Ruby doesn't have an overall Boolean class, we have to use this hack to check if boolean
      private_info = false unless !!private_info == private_info

      user_doc = get_user(user)

      # move values over from database and format them
      user_info = %i(user first_name last_name grad_year).each_with_object({}) do |key, memo|
        memo[key] = user_doc[key]
      end
      user_info[:password] = 'Hunter2' # FIXME: shows up as '*******' for me? 
      user_info[:grade] = grad_year_to_grade(user_info[:grad_year])
      user_info[:school] = grade_to_school(user_info[:grade])

      if private_info
        # programmatically validate these since it looks really ugly when done manually
        %i(canvas_url portal_url).each do |key|
          next if user_doc[key].nil?
          user_info[key] = user_doc[key].is_a?(String) ? user_doc[key] : nil
        end
      end

      user_info
    end

    def change_info(user, info)
      raise TypeError, 'invalid update information' unless info.is_a?(Hash)
      return if info.empty?

      set = %i(first_name last_name).each_with_object({}) do |key, memo|
        memo[key] = info[key] if info[key].is_a?(String)
      end

      if info[:grad_year].is_a?(Integer)
        set[:grad_year] = info[:grad_year]
      end

      return if set.empty?

      # convert back to strings and camel case keys
      # to keep compatibility with the JS API
      set.transform_keys! do |k|
        case k
        when :canvas_url then 'canvasURL'
        when :portal_url then 'portalURL'
        else k.to_s.camelize(:lower)
        end
      end

      DB[:users].update_one(
        {user: user},
        {'$set' => set},
        {upsert: true}
      )

      nil
    end

    def school_ends
      current = Time.now
      last_day_this_year = last_friday_may

      if last_day_this_year > current
        last_day_this_year
      else
        last_friday_may(current.year + 1)
      end
    end

    def grad_year_to_grade(grad_year)
      return nil unless grad_year.is_a?(Integer)

      current = Time.now
      year_diff = current.year - grad_year

      # implicitly returns grade
      # value depends on if the school year is over
      grade = 12 + year_diff
      current > last_friday_may ? grade + 1 : grade
    end

    def grade_to_grad_year(grade)
      return nil unless grade.is_a?(Integer)

      current = Time.now

      grade -= 1 if current > last_friday_may
      year_diff = grade - 12

      current.year - year_diff
    end

    def grade_to_school(grade)
      return 'upperschool' if !grade.is_a?(Numeric) || grade >= 9
      return 'lowerschool' if grade < 5
      'middleschool'
    end

    def last_friday_may(year = Time.now.year)
      year = Time.now.year unless year.is_a?(Integer)

      last_day_of_may = Time.new(year, 5)
                  .end_of_month
                  .beginning_of_day +
                  11.hours +
                  30.minutes

      weekday = last_day_of_may.wday

      case weekday
      when 5
        # last day is already Friday
        last_day_of_may
      when 6
        # last day is Saturday
        last_day_of_may - 1.day
      else
        # subtract weekday to return to Sunday
        # subtract 2 to go back to Friday
        last_day_of_may - (weekday + 2).days
      end
    end

    class << self
      alias get get_user
    end
  end
end