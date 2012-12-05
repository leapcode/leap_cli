$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__) + '/../lib')
require 'rubygems'
require 'minitest/autorun'
require 'leap_cli'

class MiniTest::Unit::TestCase
  attr_accessor :ruby_path

  # Add global extensions to the test case class here

  def setup
    LeapCli::Path.set_platform_path(test_platform_path)
    LeapCli::Path.set_provider_path(test_provider_path)
  end

  def manager
    @manager ||= begin
      manager = LeapCli::Config::Manager.new
      manager.load
      manager
    end
  end

  def base_path
    File.expand_path '../..', __FILE__
  end

  def leap_bin(*args)
    `#{ruby_path} #{base_path}/bin/leap #{args.join ' '}`
  end

  def test_platform_path
    "#{base_path}/test/leap_platform"
  end

  def test_provider_path
    "#{base_path}/test/provider"
  end

  def with_multiple_rubies(&block)
    ['ruby1.8', 'ruby1.9.1'].each do |ruby|
      self.ruby_path = `which #{ruby}`.strip
      next unless ruby_path.chars.any?
      yield
    end
    self.ruby_path = ""
  end

end
