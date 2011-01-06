require 'rubygems'

require 'trollop'

require 'password_manager_defaults.rb'

COMMAND_LINE_OPTIONS_PARSER = Trollop::Parser.new do
  version "pm² (Prof. MAADs password manager) 0.1 (c) 2010 Prof. MAAD" 
  banner "Usage: pmpm [-ihv] [-f/--database DB]"

  opt :interactive, 'Drops you to an interactive shell-style mode', :short => '-i'
  opt :database, 'The password database file to use', :short => '-f', :type => String
end
