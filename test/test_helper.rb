$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__) + '/../lib')
require 'rubygems'
require 'minitest/autorun'
require 'leap_cli'

class MiniTest::Unit::TestCase

  # Add global extensions to the test case class here

  def manager
    @manager ||= begin
      LeapCli::Path.set_root(File.dirname(__FILE__))
      manager = LeapCli::Config::Manager.new
      manager.load
      manager
    end
  end

end
