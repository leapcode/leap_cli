require 'rubygems'
require File.expand_path('../../lib/leap_cli/load_paths', __FILE__)
require 'bundler/setup'
require 'minitest/autorun'
require 'leap_cli'

class Minitest::Test
  attr_accessor :ruby_path

  # Add global extensions to the test case class here

  def setup
    LeapCli.leapfile.load(test_provider_path)
    LeapCli::Path.set_platform_path(LeapCli.leapfile.platform_directory_path)
    LeapCli::Path.set_provider_path(LeapCli.leapfile.provider_directory_path)
  end

  def manager
    @manager ||= begin
      manager = LeapCli::Config::Manager.new
      manager.load
      manager
    end
  end

  def provider
    manager.provider
  end

  def base_path
    File.expand_path '../..', __FILE__
  end

  def leap_bin(*args)
    `cd #{test_provider_path} && #{ruby_path} #{base_path}/bin/leap --no-color #{args.join ' '}`
  end

  #def test_platform_path
  #  "#{base_path}/test/leap_platform"
  #end

  def test_provider_path
    "#{base_path}/test/provider"
  end

  def with_multiple_rubies(&block)
    if ENV["RUBY"]
      ENV["RUBY"].split(',').each do |ruby|
        self.ruby_path = `which #{ruby}`.strip
        next unless ruby_path.chars.any?
        yield
      end
    else
      self.ruby_path = `which ruby`.strip
      yield
    end
    self.ruby_path = ""
  end

end
