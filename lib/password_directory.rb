require 'sqlite3'

class PasswordDirectory
  attr_accessor :name
  attr_accessor :parent
  attr_accessor :id

  @@instances = Hash.new

  def self.create(values)
    if values['id']
      if @@instances[values['id'].to_i]
        return @@instances[values['id'].to_i]
      else
        instance = PasswordDirectory.new(values)
        @@instances[instance.id] = instance
      end
    else
      return PasswordDirectory.new(values)
    end
  end

  def initialize(values)
    @id = values['id'].to_i unless values['id'].nil?
    @name = values['name']
    @parent = values['parent']
  end

  def name
    return SQLite3::Database.quote(@name)
  end
  def parent
    return nil if @parent.nil?
    return @parent.to_i
  end

  def id=(new_id)
    if @id.nil? # you can only set the id once
      @id = new_id.to_i
      @@instances[@id] = self
    end
  end

  def to_i
    return id
  end
end
