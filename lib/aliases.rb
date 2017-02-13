require 'active_support/core_ext/string/inflections'

require_relative 'classes'
require_relative 'users'

class MyMICDS
  module Aliases
    Error = Class.new(StandardError)

    AlreadyExistsError = Class.new(Error)
    ClassDNEError = Class.new(Error)

    TYPES = %w(canvas portal)

    module_function

    def add_alias(user, type, class_string, class_id)
      raise TypeError, 'invalid class string' unless class_string.is_a?(String)
      raise TypeError, 'invalid class id' unless class_id.is_a?(String)

      user_doc = Users.get(user)

      has_alias, class_obj = get_alias_class(user, type, class_string)

      raise AlreadyExistsError, 'alias already exists for a class' if has_alias

      classes = Classes.get(user)

      valid_class_obj = nil
      classes.each do |klass|
        if klass['_id'].to_s == class_id
          valid_class_obj = klass
          break
        end
      end

      raise ClassDNEError, 'native class does not exist' unless valid_class_obj

      DB[:aliases].insert_one(
        user: user_doc['_id'],
        type: type,
        classNative: valid_class_obj['_id'],
        classRemote: class_string
      ).inserted_id
    end

    def list_aliases
      # TODO
    end

    def map_aliases
      # TODO
    end

    def delete_alias
      # TODO
    end

    def get_alias_class(user, type, class_input)
      raise ArgumentError, 'invalid alias type' unless TYPES.include?(type)
      # return the current value just in case it's already a class object
      return false, class_input unless class_input.is_a?(String)

      user_doc = Users.get(user)

      aliases = DB[:aliases].find(user: user_doc['_id'], type: type, classRemote: class_input).to_a
      return false, class_input if aliases.empty?

      Classes.get(user).each do |klass|
        return true, klass if aliases[0]['classNative'] == klass['_id']
      end

      # return input if there was no valid class
      return false, class_input
    end

    def delete_classless
      # TODO
    end

    class << self
      alias add add_alias
      alias list list_aliases
      alias map_list map_aliases
      alias delete delete_alias
      alias get_class get_alias_class
    end
  end
end