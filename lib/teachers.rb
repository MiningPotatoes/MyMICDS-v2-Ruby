require 'active_support/core_ext/string/inflections'

class MyMICDS
  module Teachers
    PREFIXES = %w(Mr. Mrs.)
    TeacherNotFoundError = Class.new(StandardError)

    module_function

    def add_teacher(teacher)
      raise TypeError, 'invalid teacher hash' unless teacher.is_a?(Hash)
      raise ArgumentError, 'invalid teacher prefix' unless PREFIXES.include?(teacher['prefix'])
      %w(firstName lastName).each do |key|
        raise TypeError, "invalid #{key.underscore.tr('_', ' ')}" unless teacher[key].is_a?(String)
      end

      teacherdata = DB[:teachers]

      teacherdata.update_one(
        teacher,
        teacher,
        upsert: true
      )

      # we have to return the teacher ObjectId since it's needed as an argument for the rest of these methods
      teacherdata.find(teacher).to_a[0]['_id']
    end

    def get_teacher(teacher_id)
      raise TypeError, 'invalid teacher ID' unless teacher_id.is_a?(BSON::ObjectId)

      teacher_docs = DB[:teachers].find(_id: teacher_id).to_a
      raise TeacherNotFoundError, "teacher with id #{teacher_id} not found in database" if teacher_docs.empty?

      teacher_docs[0]
    end

    def list_teachers
      DB[:teachers].find.to_a
    end

    def delete_teacher(teacher_id)
      raise TypeError, 'invalid teacher ID' unless teacher_id.is_a?(BSON::ObjectId)

      DB[:teachers].delete_one(_id: teacher_id) if classes_taught(teacher_id).empty?

      nil
    end

    def classes_taught(teacher_id)
      raise TypeError, 'invalid teacher ID' unless teacher_id.is_a?(BSON::ObjectId)

      DB[:classes].find(teacher: teacher_id).to_a
    end

    def delete_classless
      # in the JS API, this is accomplished with some recursion BS
      # because asynchrony or something
      # but this is Ruby, so screw that
      DB[:teachers].find.each {|t| delete_teacher(t['_id'])}
    end

    class << self
      alias add add_teacher
      alias get get_teacher
      alias list list_teachers
      alias delete delete_teacher
    end
  end
end