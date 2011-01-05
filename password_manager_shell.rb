require 'rubygems'

require 'password'
require 'highline'
require 'cmd'
require 'trollop'
require 'shellwords'

require 'password_manager.rb'
require 'password_directory.rb'
require 'password_node.rb'

require 'pp'

class PasswordManagerShell < Cmd
  def initialize(password_manager)
    super()
    @password_manager = password_manager
    @highline = HighLine.new

    @working_dir = Array.new

    @method_options = Hash.new
    setup_options
  end

  doc :ls, "List directory"
  def do_ls(args)
    options, args = extract_options(:ls, args)
    if args.empty?
      ls([], options[:long], options[:recursive])
    else
      dirs = args[0].split("/")
      ls(dirs, ptions[:long], options[:recursive])
    end
  end
  doc :ll, "alias for ls -l"
  def do_ll(args)
    if args.nil?
      do_ls("-l")
    else
      do_ls("-l "+args)
    end
  end
  
  doc :cd, "Change directory"
  def do_cd(args)
    if args.nil? or args.empty?
      @working_dir.clear
    else
      dirs = args.split("/")
      new_working_dir = construct_new_working_dir(dirs)
      if new_working_dir.nil?
        puts "No such directory"
        return
      end

      @working_dir = new_working_dir
    end
  end

  doc :mkdir, "Create directory"
  def do_mkdir(args)
    options, args = extract_options(:mkdir, args)
    if args.empty?
      puts "No directory given"
    else
      dirs = args[0].split("/")
      mkdir(dirs, options[:parents])
    end
  end
  doc :rmdir, "Remove empty directory"
  def do_rmdir(args)
    if args.nil? or args.empty?
      puts "No directory given"
    else
      dirs = args.split("/")
      new_dirs = construct_new_working_dir(dirs, true)
      if new_dirs.nil?
        puts "No such directory"
      else
        dir_to_delete = new_dirs.last
        # check if dir is empty
        if @password_manager.list_directory(dir_to_delete).empty?
          @password_manager.delete_directory(dir_to_delete)
        else
          puts "Directory is not empty"
        end
      end
    end
  end
  doc :rm, "Recursively remove directory or node"
  def do_rm(args)
    if args.nil? or args.empty?
      puts "No directory or node given"
    else
      dirs = args.split("/")
      new_dirs = construct_new_working_dir(dirs, false)
      if new_dirs.nil?
        puts "No such directory or node"
      elsif new_dirs.last.nil? # last element of path was not a directory
        new_dirs.pop
        node = @password_manager.get_node(dirs.last, (new_dirs.last.nil? ? nil : new_dirs.last.to_i))
        if node.nil?
          puts "No such directory or node"
        else
          @password_manager.delete_node(node.id)
        end
      else # we need to recursively delete a directory
        @password_manager.delete_recursively(new_dirs.last)
      end
    end
  end
  doc :mv, "move items to new position"
  def do_mv(args)
    options, args = extract_options(:find, args)
  end
  
  doc :find, "find nodes"
  def do_find(args)
    options, args = extract_options(:find, args)
  end

  doc :add, "Add a new node"
  def do_add(args)
    if args.nil? or args.empty?
      puts "No node given"
    else
      dirs = args.split("/")
      node_name = dirs.pop
      new_dirs = construct_new_working_dir(dirs, true)
      if new_dirs.nil?
        puts "No such node"
      else
        node = edit_node(PasswordNode.create( 'name' => node_name, 'directory' => (new_dirs.last.nil? ? nil : new_dirs.last.to_i)), false) # user already entered the name, no need to ask again
        @password_manager.save(node)
      end
    end
  end
  doc :edit, "Edit a node"
  def do_edit(args)
    if args.nil? or args.empty?
      puts "No node given"
    else
      dirs = args.split("/")
      node_name = dirs.pop
      new_dirs = construct_new_working_dir(dirs, true)
      if new_dirs.nil?
        puts "No such node"
      else
        node = @password_manager.get_node(node_name, (new_dirs.last.nil? ? nil : new_dirs.last.to_i))
        if node.nil?
          puts "No such node"
        else
          changed_node = edit_node(node)
          @password_manager.save(changed_node)
        end
      end
    end
  end
  doc :show, "Display a node"
  def do_show(args)
    if args.nil? or args.empty?
      puts "No node given"
    else
      dirs = args.split("/")
      node_name = dirs.pop
      new_dirs = construct_new_working_dir(dirs, true)
      if new_dirs.nil?
        puts "No such node"
      else
        node = @password_manager.get_node(node_name, (new_dirs.last.nil? ? nil : new_dirs.last.to_i))
        if node.nil?
          puts "No such node"
        else
          print_node(node)
        end
      end
    end
  end
  shortcut 'cat', :show

  protected
  def setup
    prompt_with { "#{self.class.name} #{working_dir_to_string}> " }
  end

  def setup_options
    @method_options[:mkdir] = Trollop::Parser.new do
      banner "mkdir [-p] DIRECTORY"
      opt :parents, "make parent directories as need", :short => '-p'      
    end
    @method_options[:ls] = Trollop::Parser.new do
      banner "ls [-lr] [DIRECTORY]"
      opt :long, "long format", :short => '-l'
      opt :recursive, "list recursively", :short => '-R'
    end
    @method_options[:find] = Trollop::Parser.new do
      banner "find PATH [-n/--name NAME] [-U/--url URL] [-u/--user USERNAME] [-p/--pass PASSWORD] [-e/--email EMAIL] [-c/--comment COMMENT]"
      opt :name, "find by name", :short => '-n', :type => String
      opt :url, "find by URL", :short => '-U', :type => String
      opt :user, "find by username", :short => '-u', :type => String
      opt :pass, "find by password", :short => '-p', :type => String
      opt :email, "find by e-mail address", :short => '-e', :type => String
      opt :comment, "find by comment", :short => '-c', :type => String
    end
    @method_options[:add] = Trollop::Parser.new do
      banner "add [-b] NAME [-U/--url URL] [-u/--user USERNAME] [-p/--pass PASSWORD] [-e/--email EMAIL] [-c/--comment COMMENT]"
      opt :url, "set URL", :short => '-U', :type => String
      opt :user, "set username", :short => '-u', :type => String
      opt :pass, "set password", :short => '-p', :type => String
      opt :email, "set e-mail address", :short => '-e', :type => String
      opt :comment, "set comment", :short => '-c', :type => String
      opt :batch, "batch mode (do not ask for data that was not given)", :short => '-b'
    end
    @method_options[:edit] = Trollop::Parser.new do
      banner "edit [-b] NAME [-n/--name NAME] [-U/--url URL] [-u/--user USERNAME] [-p/--pass PASSWORD] [-e/--email EMAIL] [-c/--comment COMMENT]"
      opt :name, "set name", :short => '-n', :type => String
      opt :url, "set URL", :short => '-U', :type => String
      opt :user, "set username", :short => '-u', :type => String
      opt :pass, "set password", :short => '-p', :type => String
      opt :email, "set e-mail address", :short => '-e', :type => String
      opt :comment, "set comment", :short => '-c', :type => String
      opt :batch, "batch mode (do not ask for data that was not given)", :short => '-b'
    end
    @method_options[:show] = Trollop::Parser.new do
      banner "show [-q] NAME [-n/--name] [-U/--url] [-u/--user] [-p/--pass] [-e/--email] [-c/--comment]"
      opt :name, "print name", :short => '-n'
      opt :url, "print URL", :short => '-U'
      opt :user, "print username", :short => '-u'
      opt :pass, "print password", :short => '-p'
      opt :email, "print e-mail address", :short => '-e'
      opt :comment, "print comment", :short => '-c'
      opt :quiet, "'quiet mode (do not print any labels)", :short => '-q'
    end
  end
  def extract_options(method, args)
    unless args.nil?
      args_array = Shellwords.shellwords(args)
    else
      args_array = Array.new
    end
    parser = @method_options[method]
    return nil, args_array if parser.nil?

    begin
      opts = parser.parse(args_array)
    rescue Trollop::HelpNeeded
      parser.educate
    rescue Trollop::VersionNeeded
      return nil, args_array
    rescue Trollop::CommandlineError => e
      puts e
      return nil, args_array
    end

    return opts, parser.leftovers
  end

  def working_dir_to_string
    working_dir_string = @working_dir.map { |dir| dir.name }.join("/")
    result = "/#{working_dir_string}"
    result += "/" unless result[-1,1] == "/"

    return result
  end

  def cleanup_path(path)
    path.delete(".")
    
    while pos = path.index("..")
      if pos == 0
        path.delete_at(0)
      else
        path.delete_at(pos-1)
        path.delete_at(pos-1)
      end
    end

    return path
  end
  def construct_new_working_dir(new_dirs, must_exist = true)
    if new_dirs.empty?
      return @working_dir
    else    
      if new_dirs[0].empty? # absolute path
        dirs = new_dirs
        dirs.delete_at(0)
      else
        dirs = @working_dir.map{ |dir| dir.name }.concat(new_dirs)
      end

      new_working_dir = get_directories_from_path(dirs, must_exist)

      return new_working_dir
    end    
  end
  def get_directories_from_path(path, must_exist)
    result = Array.new

    path = cleanup_path(path) # manage "." and ".."

    path.each do |dir_name|
      dir = @password_manager.get_directory(dir_name, result.last)
      return nil if (dir.nil? and (dir_name != path.last or must_exist))
      
      result.push(dir)
    end

    return result
  end
  

  def ls(dirs, long = false, recursive = false)
    dirs_string = dirs
    dirs = construct_new_working_dir(dirs)
    if dirs.nil?
      puts "No such directory"
      return
    end
    
    content = @password_manager.list_directory(dirs.last)
    if recursive
      if dirs_string.empty?
        puts ".:"
      else
        puts "./#{dirs_string.join('/')}:"
      end
    end

    if long
      content_strings = content.map do |item|
        result = ""
        if item.class == PasswordDirectory
          result += "d "
        elsif item.class == PasswordNode
          result += "n "
        end
        result += item.name
        result
      end
    else
      content_strings = content.map { |item| item.name }
    end
    print @highline.list(content_strings, (long ? :rows : :columns_across)) unless content.empty? # need to work around a bug in HighLine were list([], :columns_across) throws an exception

    if recursive
      puts ""
      content.each do |item|
        next unless item.class == PasswordDirectory
        
        new_dirs_string = dirs_string.dup
        new_dirs_string.push(item.name)
        ls(new_dirs_string, long, recursive)
      end
    end
  end  
  def mkdir(dirs, create_parents = false)
    new_dirs = construct_new_working_dir(dirs, false)
    if new_dirs.nil?
      if create_parents
        mkdir(dirs[0..-2], create_parents)
        mkdir(dirs, false)
        return
      else
        puts "No such directory"
      end      
    elsif new_dirs.last.nil?
      new_dirs.pop
      new_directory = PasswordDirectory.create( 'name' => dirs.last, 'parent' => (new_dirs.last.nil? ? nil : new_dirs.last.to_i) )
      @password_manager.save(new_directory)
    else
      puts "Directory already exists"
    end
  end

  def print_node(node)
    output_array = Array.new
    output_array += ["Name:", node.name] unless (node.name.nil? or node.name.empty?)
    output_array += ["URL:", node.url] unless (node.url.nil? or node.url.empty?)
    output_array += ["Username:", node.username] unless (node.username.nil? or node.username.empty?)
    output_array += ["Password:", node.password] unless (node.password.nil? or node.password.empty?)
    output_array += ["E-Mail:", node.email] unless (node.email.nil? or node.email.empty?)
    output_array += ["Comment:", node.comment] unless (node.comment.nil? or node.comment.empty?)

    print @highline.list(output_array, :columns_across, 2)
  end
  def edit_node(node, ask_name = true)
    if ask_name
      node.name = @highline.ask("Name? ") do |q|
        q.default = node.name
        q.validate = Proc.new { |answer| !answer.include?("/") }
      end
    end
    node.url = @highline.ask("URL? ") { |q| q.default = node.url }
    node.username = @highline.ask("Username? ") { |q| q.default = node.username }
    node.password = @highline.ask("Password? ") { |q| q.default = node.password }
    node.email = @highline.ask("E-Mail? ") { |q| q.default = node.email }
    node.comment = @highline.ask("Comment? ") { |q| q.default = node.comment }

    return node
  end
end
