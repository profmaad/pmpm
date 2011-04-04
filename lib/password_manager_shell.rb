require 'rubygems'

require 'password'
require 'highline'
require 'cmd'
require 'trollop'
require 'shellwords'
require 'clipboard'
require 'rbconfig'

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
    return if options.nil?
    if args.empty?
      ls([], options[:long], options[:recursive])
    else
      args.each do |arg|
        dirs = arg.split("/")
        unless args.length == 1
          if dirs.empty?
            puts ".:"
          elsif dirs[0].empty?
            puts "#{arg}:"
          else
            puts "./#{arg}:"
          end
        end
        ls(dirs, options[:long], options[:recursive])
        puts "" unless arg == args.last
      end
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
    return if options.nil?
    if args.empty?
      puts "No directory given"
    else
      args.each do |arg|
        dirs = arg.split("/")
        mkdir(dirs, options[:parents])
      end
    end
  end
  doc :rmdir, "Remove empty directory"
  def do_rmdir(args)
    options, args = extract_options(:rmdir, args)
    if args.empty?
      puts "No directory given"
    else
      args.each do |arg|
        dirs = arg.split("/")
        new_dirs = construct_new_working_dir(dirs, true)
        if new_dirs.nil?
          puts "#{arg}: No such directory"
        else
          dir_to_delete = new_dirs.last
          # check if dir is empty
          if @password_manager.list_directory(dir_to_delete).empty?
            @password_manager.delete_directory(dir_to_delete)
          else
            puts "#{arg} is not empty"
          end
        end
      end
    end
  end
  doc :rm, "Recursively remove directory or node"
  def do_rm(args)
    options, args = extract_options(:rm, args)
    if args.empty?
      puts "No directory or node given"
    else
      args.each do |arg|
        dirs = arg.split("/")
        new_dirs = construct_new_working_dir(dirs, false)
        if new_dirs.nil?
          puts "#{arg}: No such directory or node"
        elsif new_dirs.last.nil? # last element of path was not a directory
          new_dirs.pop
          node = @password_manager.get_node(dirs.last, (new_dirs.last.nil? ? nil : new_dirs.last.to_i))
          if node.nil?
            puts "#{arg}: No such directory or node"
          else
            @password_manager.delete_node(node.id)
          end
        else # we need to recursively delete a directory
          @password_manager.delete_recursively(new_dirs.last)
        end
      end
    end
  end
  doc :mv, "move items to new position"
  def do_mv(args)
    options, args = extract_options(:mv, args)
    if args.empty?
      puts "No items given"
    elsif args.length < 2
      puts "Destination missing"
    else
      destination = args.pop.split("/")
      sources = args.map { |item| item.split("/") }

      dest_path = construct_new_working_dir(destination, false)
      if dest_path.nil?
        puts "Destination doesn't exist"
      elsif dest_path.last.nil? and sources.length > 1
        puts "Multiple sources but destination isn't a directory"
      elsif dest_path.last.nil?
        dest_path.pop       

        dest_node = @password_manager.get_node(destination.last, (dest_path.last.nil? ? nil : dest_path.last.to_i))
        dest_name = destination.last
        dest_dir = (dest_path.last.nil? ? nil : dest_path.last.to_i)
        
        source = sources[0]
        source_path = construct_new_working_dir(source, false)
        if source_path.nil?
          puts "Source '#{source.join('/')}' doesn't exist"
        elsif source_path.last.nil?
          source_path.pop
          source_node = @password_manager.get_node(source.last, (source_path.last.nil? ? nil : source_path.last.to_i))
          if source_node.nil?
            puts "Source '#{source.join('/')}' doesn't exist"
          else
            # move source to dest
            unless dest_node.nil?
              really_overwrite = @highline.agree("Do you really want to overwrite '#{destination.join('/')}'? ")
              return unless really_overwrite
            end
            
            source_node.directory = dest_dir
            source_node.name = dest_name
            @password_manager.delete_node(dest_node.id) unless dest_node.nil?
            @password_manager.save(source_node)
          end
        else
          puts "Can't overwrite node with directory"
        end
      else
        dest = dest_path.last

        sources.each do |source|
          source_path = construct_new_working_dir(source, false)
          if source_path.nil?
            puts "Source '#{source.join('/')}' doesn't exist"
          elsif source_path.last.nil?
            source_path.pop
            source_node = @password_manager.get_node(source.last, (source_path.last.nil? ? nil : source_path.last.to_i))
            if source_node.nil?
              puts "Source '#{source.join('/')}' doesn't exist"
            else
              # move source to dest
              source_node.directory = dest.id
              @password_manager.save(source_node)
            end
          else
            source_dir = source_path.last
            source_dir.parent = dest.id
            @password_manager.save(source_dir)
          end
        end
      end
    end
  end
  
  doc :find, "find nodes"
  def do_find(args)
    options, args = extract_options(:find, args)
    return if options.nil?

    if args.empty?
      search_root = [""]
    else
      search_root = args[0].split("/")
    end

    search_path = construct_new_working_dir(search_root, true)
    if search_path.nil?
      puts "Search root doesn't exist"
    else
      properties = options.dup
      properties[:parent] = (search_path.last.nil? ? nil : search_path.last.to_i)
      properties[:directory] = properties[:parent]

      if search_root.empty?
        search_dir = "."
      elsif search_root[0].empty?
        search_dir = "#{search_root.join('/')}"
      else
        search_dir = "./#{search_root.join('/')}"
      end

      find(search_dir, properties)
    end
  end

  doc :add, "Add a new node"
  def do_add(args)
    options, args = extract_options(:add, args)
    return if options.nil?
    if args.empty?
      puts "No node given"
    else
      dirs = args[0].split("/")
      node_name = dirs.pop
      new_dirs = construct_new_working_dir(dirs, true)
      if new_dirs.nil?
        puts "No such node"
      elsif !@password_manager.get_node(node_name, (new_dirs.last.nil? ? nil : new_dirs.last.to_i)).nil? or !@password_manager.get_directory(node_name, (new_dirs.last.nil? ? nil : new_dirs.last.to_i)).nil?
        puts "Name already exists"
      else
        node_data = Hash.new
        node_data['name'] = node_name
        node_data['url'] = options[:url]
        node_data['username'] = options[:user]
        node_data['password'] = options[:pass]
        node_data['email'] = options[:email]
        node_data['comment'] = options[:comment]
        node_data['directory'] = (new_dirs.last.nil? ? nil : new_dirs.last.to_i)
        node = PasswordNode.create(node_data)
        unless options[:batch]
          node = edit_node(node, options.merge({:name => node_name})) # user already entered the name, no need to ask again
        end
        @password_manager.save(node)
      end
    end
  end
  doc :edit, "Edit a node"
  def do_edit(args)
    options, args = extract_options(:edit, args)
    return if options.nil?
    if args.empty?
      puts "No node given"
    else
      dirs = args[0].split("/")
      node_name = dirs.pop
      new_dirs = construct_new_working_dir(dirs, true)
      if new_dirs.nil?
        puts "No such node"
      else
        node = @password_manager.get_node(node_name, (new_dirs.last.nil? ? nil : new_dirs.last.to_i))
        if node.nil?
          puts "No such node"
        else
          node.name = options[:name] unless options[:name].nil?
          node.url = options[:url] unless options[:url].nil?
          node.username = options[:user] unless options[:user].nil?
          node.password = options[:pass] unless options[:pass].nil?
          node.email = options[:email] unless options[:email].nil?
          node.comment = options[:comment] unless options[:comment].nil?
          unless options[:batch]
            node = edit_node(node, options)
          end
          @password_manager.save(node)
        end
      end
    end
  end
  doc :show, "Display a node"
  def do_show(args)
    options, args = extract_options(:show, args)
    return if options.nil?
    if args.empty?
      puts "No node given"
    else
      dirs = args[0].split("/")
      node_name = dirs.pop
      new_dirs = construct_new_working_dir(dirs, true)
      if new_dirs.nil?
        puts "No such node"
      else
        node = @password_manager.get_node(node_name, (new_dirs.last.nil? ? nil : new_dirs.last.to_i))
        if node.nil?
          puts "No such node"
        else
          no_requested_values = (!options[:name] and !options[:url] and !options[:user] and !options[:pass] and !options[:email] and !options[:comment])
          print_node(node, (no_requested_values ? {} : options), options[:quiet])
          Clipboard.copy(node.password) if options[:copy]
          open_url_in_browser(node.url) if options[:open]
        end
      end
    end
  end
  shortcut 'cat', :show

  def complete_ls(line)
    last_slash = line.rindex("/")
    if last_slash
      dir = line[0,last_slash]
      to_complete = line[last_slash+1..-1]
    else
      dir = ""
      to_complete = line
    end

    dirs = construct_new_working_dir(dir.split("/"))
    if dirs.nil?
      puts "#{dir}:#{to_complete}"
      return []
    else
      content = @password_manager.list_directory(dirs.last)
      content_strings = content.map { |item| "#{dir}/#{item.name}" }
      return completion_grep(content_strings, line)
    end
  end
  alias :complete_ll :complete_ls
  alias :complete_add :complete_ls
  alias :complete_cd :complete_ls
  alias :complete_edit :complete_ls
  alias :complete_find :complete_ls
  alias :complete_mkdir :complete_ls
  alias :complete_mv :complete_ls
  alias :complete_rm :complete_ls
  alias :complete_rmdir :complete_ls
  alias :complete_show :complete_ls

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
      banner "show [-qo] [--copy] NAME [-n/--name] [-U/--url] [-u/--user] [-p/--pass] [-e/--email] [-c/--comment]"
      opt :name, "print name", :short => '-n'
      opt :url, "print URL", :short => '-U'
      opt :user, "print username", :short => '-u'
      opt :pass, "print password", :short => '-p'
      opt :email, "print e-mail address", :short => '-e'
      opt :comment, "print comment", :short => '-c'
      opt :quiet, "quiet mode (do not print any labels)", :short => '-q'
      opt :copy, "copy password to clipboard"
      opt :open, "open URL in browser", :short => '-o'
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

  def open_url_in_browser(url)
    if RbConfig::CONFIG['host_os'] =~ /mswin|windows|cygwin|mingw/i
      system("start #{url}")
    elsif RbConfig::CONFIG['host_os'] =~ /linux/i
      system("xdg-open #{url}")
    elsif RbConfig::CONFIG['host_os'] =~ /darwin/i
      system("open #{url}")
    end
  end

  def ls(dirs, long = false, recursive = false)
    dirs_string = dirs.dup
    dirs = construct_new_working_dir(dirs)
    if dirs.nil?
      puts "No such directory"
      return
    end
    
    content = @password_manager.list_directory(dirs.last)
    if recursive
      if dirs_string.empty?
        puts ".:"
      elsif dirs_string[0].empty?
        puts "#{dirs_string.join('/')}:"
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
  def find(search_dir, properties)
    dir_props = Hash.new
    dir_props[:parent] = properties[:parent]
    dirs = @password_manager.find_directories(dir_props)
    unless dirs.nil?
      dirs.each do |dir|
        new_props = properties.dup
        new_props[:parent] = dir.to_i
        new_props[:directory] = dir.to_i

        find(search_dir + "/#{dir.name}", new_props)
      end
    end

    nodes = @password_manager.find_nodes(properties)
    unless nodes.nil?
      nodes.each do |node|
        puts "#{search_dir}/#{node.name}"
      end
    end
  end

  def print_node(node, requested_values = {}, quiet = false)
    if quiet
      puts node.name if (requested_values.empty? or requested_values[:name])
      puts node.url if (requested_values.empty? or requested_values[:url])
      puts node.username if (requested_values.empty? or requested_values[:user])
      puts node.password if (requested_values.empty? or requested_values[:pass])
      puts node.email if (requested_values.empty? or requested_values[:email])
      puts node.comment if (requested_values.empty? or requested_values[:comment])
    else
      output_array = Array.new
      output_array += ["Name:", node.name] unless (node.name.nil? or node.name.empty? or (!requested_values.empty? and !requested_values[:name]))
      output_array += ["URL:", node.url] unless (node.url.nil? or node.url.empty? or (!requested_values.empty? and !requested_values[:url]))
      output_array += ["Username:", node.username] unless (node.username.nil? or node.username.empty? or (!requested_values.empty? and !requested_values[:user]))
      output_array += ["Password:", node.password] unless (node.password.nil? or node.password.empty? or (!requested_values.empty? and !requested_values[:pass]))
      output_array += ["E-Mail:", node.email] unless (node.email.nil? or node.email.empty? or (!requested_values.empty? and !requested_values[:email]))
      output_array += ["Comment:", node.comment] unless (node.comment.nil? or node.comment.empty? or (!requested_values.empty? and !requested_values[:comment]))
      
      print @highline.list(output_array, :columns_across, 2)
    end
  end
  def edit_node(node, given_values = {})
    unless given_values[:name]
      node.name = @highline.ask("Name? ") do |q|
        q.default = node.name
        q.validate = Proc.new { |answer| !answer.include?("/") }
      end
    end
    node.url = @highline.ask("URL? ") { |q| q.default = node.url } unless given_values[:url]
    node.username = @highline.ask("Username? ") { |q| q.default = node.username } unless given_values[:user]
    node.password = @highline.ask("Password? ") { |q| q.default = node.password } unless given_values[:pass]
    node.email = @highline.ask("E-Mail? ") { |q| q.default = node.email } unless given_values[:email]
    node.comment = @highline.ask("Comment? ") { |q| q.default = node.comment } unless given_values[:comment]

    return node
  end
end
