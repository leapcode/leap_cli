require 'rubygems'
require File.expand_path('../../lib/leap_cli/load_paths', __FILE__)
require 'bundler/setup'
require 'minitest/autorun'
require 'leap_cli'
require 'gli'
require 'fileutils'

DEBUG = true
TEST  = true

module LeapCli::Commands
  extend GLI::App
end

class Minitest::Test
  attr_accessor :ruby_path

  # Add global extensions to the test case class here

  def initialize(*args)
    super(*args)
    LeapCli::Bootstrap::setup([], provider_path)
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
    cmd = "cd #{provider_path} && PLATFORM_DIR=#{platform_path} #{base_path}/bin/leap --debug --yes --no-color #{args.join ' '}"
    `#{cmd}`
  end

  def leap_bin!(*args)
    output = leap_bin(*args)
    exit_code = $?
    assert_equal 0, exit_code,
      "The command `leap #{args.join(' ')}` should have exited 0 " +
      "(was #{exit_code}).\n" +
      "Output was: #{output}"
    output
  end

  def provider_path
    "#{base_path}/test/provider"
  end

  #
  # for tests, we assume that the leap_platform code is
  # in a sister directory to leap_cli.
  #
  def platform_path
    ENV['PLATFORM_DIR'] || "#{base_path}/../leap_platform"
  end

  def cleanup_files(*args)
    Dir.chdir(provider_path) do
      args.each do |file|
        FileUtils.rm_r(file) if File.exist?(file)
      end
    end
  end

  #
  # we no longer support ruby 1.8, but this might be useful in the future
  #
  def with_multiple_rubies(&block)
    yield
  #  if ENV["RUBY"]
  #    ENV["RUBY"].split(',').each do |ruby|
  #      self.ruby_path = `which #{ruby}`.strip
  #      next unless ruby_path.chars.any?
  #      yield
  #    end
  #  else
  #    self.ruby_path = `which ruby`.strip
  #    yield
  #  end
  #  self.ruby_path = ""
  end

end
