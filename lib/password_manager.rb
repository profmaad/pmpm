require 'rubygems'

require 'password'
require 'highline'

require 'password_database.rb'
require 'password_directory.rb'
require 'password_node.rb'
require 'password_manager_defaults.rb'

require 'pp'

class PasswordManager
  def initialize(db_file)
    @db_file = db_file
    @db = nil
    @description = nil
    @highline = nil
    @valid = true
    
    init_highline
    begin
      init_database(@db_file)
    rescue Exception => e
      @valid = false
      puts "db initialization failed: #{e.message}"
    end
  end

  def init_highline
    @highline = HighLine.new
  end
  def init_database(file)
    # first, check if the file already exists or whether we need to create a new one
    new_db = !File.exist?(file)
    if new_db
      puts "creating new database at #{file}"
    end
      open_database(file)
    if new_db
      @description = @highline.ask("Description for #{file}: ")
      init_tables
    end
    
    check_database
  end

  def init_tables
    @db.execute("CREATE TABLE password_manager_meta (id INTEGER PRIMARY KEY, version INTEGER, desc TEXT);")
    desc_quoted = SQLite3::Database.quote(@description)
    @db.execute("INSERT INTO password_manager_meta (version, desc) VALUES (#{DB_VERSION}, '#{desc_quoted}');")
    @db.execute("CREATE TABLE directories (id INTEGER PRIMARY KEY, name TEXT, parent INTEGER NULL, CONSTRAINT name_unique UNIQUE (name,parent));")
    @db.execute("CREATE TABLE nodes (id INTEGER PRIMARY KEY, name TEXT NOT NULL, url TEXT, username TEXT, password TEXT, email TEXT, comment TEXT, directory INTEGER NULL, CONSTRAINT name_unique UNIQUE (name,directory));")
  end
  def open_database(file)
    password = @highline.ask("Enter password for #{file}: ") { |q| q.echo = false }

    @db = PasswordDatabase.new(file, password)
    password = nil

    @db.results_as_hash = true
    @db.type_translation = true
  end
  def check_database
    result = @db.get_first_row("SELECT * FROM password_manager_meta;")

    if result['version'].to_i < DB_VERSION
      raise "db was created with an old version, can't read it"
    elsif result['version'].to_i > DB_VERSION
      raise "db was created with a newer version, can't read it"
    end

    @description = result['desc']
  end
  def close_database
    @db.close unless @db.closed?
  end

  def valid?
    return @valid
  end

  def list_directory(dir)
    if dir
      dirs = @db.execute("SELECT * FROM directories WHERE parent=#{dir.to_i};")
      nodes = @db.execute("SELECT * FROM nodes WHERE directory=#{dir.to_i};")
    else
      dirs = @db.execute("SELECT * FROM directories WHERE parent IS NULL;")
      nodes = @db.execute("SELECT * FROM nodes WHERE directory IS NULL;")
    end

    result = Array.new
    result = dirs.map { |row| PasswordDirectory.create(row) }
    result += nodes.map { |row| PasswordNode.create(row) }

    result.sort! { |a,b| a.name <=> b.name }

    return result
  end
  def get_directory_by_id(id)
    result = @db.get_first_row("SELECT * FROM directories WHERE id=#{id.to_i};")

    return nil if result.nil?
    return PasswordDirectory.create(result)
  end
  def get_directory(name, parent)
    name_quoted = SQLite3::Database.quote(name)
    if parent.nil?
      result = @db.get_first_row("SELECT * FROM directories WHERE parent IS NULL and name='#{name_quoted}';")
    else
      result = @db.get_first_row("SELECT * FROM directories WHERE parent=#{parent.to_i} AND name='#{name_quoted}';")
    end

    return nil if result.nil?
    return PasswordDirectory.create(result)
  end
  def get_node_by_id(id)
    result = @db.get_first_row("SELECT * FROM nodes WHERE id=#{id.to_i};")

    return nil if result.nil?
    return PasswordNode.create(result)
  end
  def get_node(name, directory)
    name_quoted = SQLite3::Database.quote(name)
    if directory.nil?
      result = @db.get_first_row("SELECT * FROM nodes WHERE directory IS NULL and name='#{name_quoted}';")
    else
      result = @db.get_first_row("SELECT * FROM nodes WHERE directory=#{directory.to_i} AND name='#{name_quoted}';")
    end

    return nil if result.nil?
    return PasswordNode.create(result)
  end

  def delete_directory(id)
    @db.execute("DELETE FROM directories WHERE id=#{id.to_i}")
  end
  def delete_node(id)
    @db.execute("DELETE FROM nodes WHERE id=#{id.to_i}")
  end
  def delete_recursively(object)
    if object.class == PasswordNode
      delete_node(object.id)
    elsif object.class == PasswordDirectory
      content = list_directory(object)
      content.each do |item|
        delete_recursively(item)
      end

      delete_directory(object)
    else
      raise 'Invalid class'
    end
  end

  def save(object)
    if(object.class == PasswordDirectory)
      if(object.id)
        if object.parent
          @db.execute("UPDATE directories SET name='#{object.name}', parent=#{object.parent} WHERE id=#{object.id.to_i};")
        else
          @db.execute("UPDATE directories SET name='#{object.name}', parent = NULL WHERE id=#{object.id.to_i};")
        end
      else
        if object.parent
          @db.execute("INSERT INTO directories (name, parent) VALUES ('#{object.name}', #{object.parent});")
        else
          @db.execute("INSERT INTO directories (name) VALUES ('#{object.name}');")
        end
        object.id = @db.last_insert_row_id
      end
    elsif(object.class == PasswordNode)
      if(object.id)
        if object.directory
          @db.execute("UPDATE nodes SET name='#{object.name}', url='#{object.url}', email='#{object.email}', username='#{object.username}', password='#{object.password}', comment='#{object.comment}', directory=#{object.directory} WHERE id=#{object.id.to_i};")
        else
          @db.execute("UPDATE nodes SET name='#{object.name}', url='#{object.url}', email='#{object.email}', username='#{object.username}', password='#{object.password}', comment='#{object.comment}', directory=NULL WHERE id=#{object.id.to_i};")
        end
      else
        if object.directory
          @db.execute("INSERT INTO nodes (name, url, email, username, password, comment, directory) VALUES ('#{object.name}', '#{object.url}', '#{object.email}', '#{object.username}', '#{object.password}', '#{object.comment}', #{object.directory});")
        else
          @db.execute("INSERT INTO nodes (name, url, email, username, password, comment) VALUES ('#{object.name}', '#{object.url}', '#{object.email}', '#{object.username}', '#{object.password}', '#{object.comment}');")
        end
        object.id = @db.last_insert_row_id
      end
    else
      raise 'Invalid class'
    end
  end
end

