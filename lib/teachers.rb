class MyMICDS
  module Teachers
    PREFIXES = %w(Mr. Mrs.)

    module_function

    def add_teacher(teacher)
      # TODO
    end

    def get_teacher(teacher_id)
      # TODO
    end

    def list_teachers
      # TODO
    end

    def delete_teacher(teacher_id)
      # TODO
    end

    def classes_taught(teacher_id)
      # TODO
    end

    def delete_classless
      # TODO
    end

    class << self
      alias add add_teacher
      alias get get_teacher
      alias list list_teachers
      alias delete delete_teacher
    end
  end
end