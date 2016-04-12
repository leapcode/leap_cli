require 'rubygems'
require File.expand_path('../../lib/leap_cli/load_paths', __FILE__)
require 'bundler/setup'
require 'minitest/autorun'
require 'leap_cli'
require 'gli'
require 'fileutils'

DEBUG = true

module LeapCli::Commands
  extend GLI::App
end

class Minitest::Test
  attr_accessor :ruby_path

  # Add global extensions to the test case class here

  def initialize(*args)
    super(*args)
    LeapCli::Bootstrap::setup([], test_provider_path)
    LeapCli::Bootstrap::load_libraries(LeapCli::Commands)
  end

  def setup
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

  def test_provider_path
    "#{base_path}/test/provider"
  end

  def cleanup_files(*args)
    Dir.chdir(test_provider_path) do
      args.each do |file|
        FileUtils.rm_r(file) if File.exist?(file)
      end
    end
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
