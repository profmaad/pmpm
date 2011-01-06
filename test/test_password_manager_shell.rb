require 'test/unit'

$: << File.expand_path(File.dirname(__FILE__) + "/../lib")
require 'password_manager_shell.rb'

class TestPasswordManagerShell < Test::Unit::TestCase
  def setup
    @shell = PasswordManagerShell.new(nil)
  end

  def test_cleanup_path
    assert_equal(["work"], @shell.send(:cleanup_path, ["..","private","..","work"]))
    assert_equal([], @shell.send(:cleanup_path, ["private","work","..",".."]))
    assert_equal(["private","work"], @shell.send(:cleanup_path, ["private",".","work"]))
    assert_equal(["private"], @shell.send(:cleanup_path, ["private",".","work",".."]))
  end
end
