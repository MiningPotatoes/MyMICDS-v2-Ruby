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

      valid_class_obj = nil
      Classes.get(user).each do |klass|
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

    def list_aliases(user)
      user_doc = Users.get(user)

      alias_list = TYPES.each_with_object({}) {|t, m| m[t] = []}

      DB[:aliases].find(user: user_doc['_id']).each do |the_alias|
        alias_list[the_alias['type']] << the_alias unless alias_list[the_alias['type']].nil?
      end

      alias_list
    end

    def map_aliases(user)
      aliases, classes = [
        Thread.new {list_aliases(user)},
        Thread.new {Classes.get(user)}
      ].map {|t| t.join.value}

      class_map = classes.each_with_object({}) {|c, m| m[c['_id'].to_s] = c}

      TYPES.each_with_object({}) do |type, memo|
        memo[type] = {}

        next unless aliases[type].is_a?(Array)
        aliases[type].each do |the_alias|
          memo[type][the_alias['classRemote']] = class_map[the_alias['classNative'].to_s]
        end
      end
    end

    def delete_alias(user, type, alias_id)
      raise ArgumentError, 'invalid alias type' unless TYPES.include?(type)

      aliases = list_aliases(user)

      valid_alias_id = nil
      aliases[type].each do |the_alias|
        if alias_id == the_alias['_id'].to_s
          valid_alias_id = the_alias['_id']
          break
        end
      end

      raise ArgumentError, 'invalid alias id' unless valid_alias_id

      DB[:aliases].delete_one(_id: valid_alias_id)

      nil
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
      aliasdata = DB[:aliases]
      classdata = DB[:classes]

      aliases, classes = [
        Thread.new {aliasdata.find.to_a},
        Thread.new {classdata.find.to_a}
      ].map {|t| t.join.value}

      aliases.each do |the_alias|
        valid_class = false
        classes.each do |the_class|
          if the_alias['classNative'] == the_class['_id']
            valid_class = true
            break
          end
        end

        unless valid_class
          aliasdata.delete_one(_id: the_alias['_id'], user: the_alias['user'])
        end
      end

      nil
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