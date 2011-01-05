class PasswordNode
  attr_accessor :id
  attr_accessor :name
  attr_accessor :url
  attr_accessor :email
  attr_accessor :username
  attr_accessor :password
  attr_accessor :comment
  attr_accessor :directory

  @@instances = Hash.new

  def self.create(values)
    if values['id']
      if @@instances[values['id'].to_i]
        return @@instances[values['id'].to_i]
      else
        instance = PasswordNode.new(values)
        @@instances[instance.id] = instance
      end
    else
      return PasswordNode.new(values)
    end
  end

  def initialize(values)
    @id = values['id'].to_i unless values['id'].nil?
    @name = values['name']
    @url = values['url']
    @email = values['email']
    @username = values['username']
    @password = values['password']
    @comment = values['comment']
    @directory = values['directory']
  end

  def name
    return nil if @name.nil?
    return SQLite3::Database.quote(@name)
  end
  def directory
    return nil if @directory.nil?
    return @directory.to_i
  end
  def url
    return nil if @url.nil?
    return SQLite3::Database.quote(@url)
  end
  def email
    return nil if @email.nil?
    return SQLite3::Database.quote(@email)
  end
  def username
    return nil if @username.nil?
    return SQLite3::Database.quote(@username)
  end
  def password
    return nil if @password.nil?
    return SQLite3::Database.quote(@password)
  end
  def comment
    return nil if @comment.nil?
    return SQLite3::Database.quote(@comment)
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
