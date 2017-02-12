require_relative 'teachers'
require_relative 'users'

class MyMICDS
  module Classes
    BLOCKS = %w(a b c d e f g sport other)
    TYPES = %w(art english history math science spanish latin mandarin german french other)

    module_function

    def upsert_class(user, schedule_class)
      # TODO
    end

    def get_classes(user)
      # TODO
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