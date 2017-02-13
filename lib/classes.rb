require 'bson'
require 'securerandom'

require_relative 'teachers'
require_relative 'users'

class MyMICDS
  module Classes
    DuplicateError = Class.new(StandardError)

    BLOCKS = %w(a b c d e f g sport other)
    TYPES = %w(art english history math science spanish latin mandarin german french other)

    HEX_DIGIT = /[0-9A-F]/i
    HEX_COLOR = /^##{"(#{HEX_DIGIT.to_s * 2})" * 3}$/
    SHORT_COLOR = /^##{"(#{HEX_DIGIT})" * 3}$/

    module_function

    def upsert_class(user, schedule_class)
      raise TypeError, 'invalid class hash' unless schedule_class.is_a?(Hash)
      raise TypeError, 'invalid class name' unless schedule_class['name'].is_a?(String)
      schedule_class['_id'] = '' unless schedule_class['_id'].is_a?(String)

      # default to other
      schedule_class['block'] = 'other' unless BLOCKS.include?(schedule_class['block'])
      schedule_class['type'] = 'other' unless TYPES.include?(schedule_class['type'])

      unless /(#{HEX_COLOR})|(#{SHORT_COLOR})/ =~ schedule_class['color']
        # here at MyMICDS, we don't play around
        # cryptographically-generated colors are the pinnacle of human technology
        schedule_class['color'] = '#' + SecureRandom.hex(3)
      end
      schedule_class['color'].upcase!

      # these keys get reused a couple times, so we'll declare them earlier
      keys = %w(name color block type)

      user_doc = Users.get(user)
      teacher_id = Teachers.add(schedule_class['teacher'])['_id']

      classdata = DB[:classes]

      classes = classdata.find(user: user_doc['_id']).to_a

      # let's check if there's a class that we're supposed to update
      valid_edit_id = false
      unless schedule_class['_id'].empty?
        classes.each do |klass|
          klass_id = klass['_id']

          if schedule_class['_id'] == klass_id.to_s
            valid_edit_id = klass_id
            break
          end
        end
      end

      # now let's check for duplicate
      dup_ids = classes.each_with_object([]) do |klass, memo|
        if schedule_class.values_at(*keys) == klass.values_at(*keys) && teacher_id == klass['teacher']
          memo << klass['_id']
        end
      end

      # if there's any duplicates, panic and give up
      unless dup_ids.empty?
        # if the edit id is still valid, then it'll be fine
        # the user could have just accidentally pressed 'save'
        # in that case, there shouldn't be an error
        if valid_edit_id
          return schedule_class
        else
          raise DuplicateError, 'tried to insert a duplicate class'
        end
      end

      id = valid_edit_id ? valid_edit_id : BSON::ObjectId.new

      insert_class = {
        '_id' => id,
        'teacher' => teacher_id,
        'user' => user_doc['_id']
      }
      keys.each {|key| insert_class[key] = schedule_class[key]}

      classdata.update_one(
        {_id: id},
        insert_class,
        upsert: true
      )

      Teachers.delete_classless
      return insert_class
    end

    def get_classes(user)
      user_doc = Users.get(user)

      classes = DB[:classes].find(user: user_doc['_id']).each do |c|
        # convert shorthand color to long form, convert to RGB values
        rgb = c['color'].gsub(SHORT_COLOR, '#\1\1\2\2\3\3').match(HEX_COLOR).captures.map {|x| x.to_i(16)}

        # ported from NPM `prisma` package
        c['textDark'] = Math.sqrt(
          ((rgb[0] ** 2) * 0.241) +
          ((rgb[1] ** 2) * 0.691) +
          ((rgb[2] ** 2) * 0.068)
        ) >= 130
      end.to_a

      teachers_list = {}

      classes.each do |klass|
        klass['user'] = user_doc['user']

        teacher_id = klass['teacher']

        if teachers_list[teacher_id].nil?
          teachers_list[teacher_id] = klass['teacher'] = Teachers.get(teacher_id)
        else
          klass['teacher'] = teachers_list[teacher_id]
        end
      end
    end

    def delete_class(user, class_id)
      # TODO
    end

    class << self
      alias upsert upsert_class
      alias get get_classes
      alias delete delete_class
    end
  end
end
