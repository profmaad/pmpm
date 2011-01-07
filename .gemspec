require 'rake'

Gem::Specification.new do |s|
  s.name = "pmpm"
  s.version = "0.1"
  s.summary = "Prof. MAADs password manager - simple password manager based on SQLite and SQLCipher"
  s.author = "Prof. MAAD aka Max Wolter"
  s.homepage = "https://github.com/profmaad/pmpm"
  s.license = "GPL-2"

  s.files = FileList["lib/**/*.rb", "bin/*", "test/*.rb", "README.md", "LICENSE"]
  s.executables << "pmpm"

  s.add_dependency("trollop", [">= 1.16.2"])
  s.add_dependency("cmd", [">= 0.7.2"])
  s.add_dependency("highline", [">= 1.6.1"])
  s.add_dependency("password", [">= 0.5.3"])
  s.add_dependency("sqlite3", [">= 1.2.4"])
  
  s.requirements << "SQLite 3, >= 3.7, sqlite.org"
  s.requirements << "SQLCipher, >= 1.1, sqlcipher.net"

  s.test_files = FileList["test/*.rb"]
end
