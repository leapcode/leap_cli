require 'gli'
require 'highline'
require 'forwardable'
require 'lib_ext/gli' # our custom extensions to gli

#
# Typically, GLI and Highline methods are loaded into the global namespace.
# Instead, here we load these into the module LeapCli::Commands in order to
# ensure that the cli logic and code is kept isolated to leap_cli/commands/*.rb
#
# no cheating!
#
module LeapCli::Commands
  extend GLI::App
  extend Forwardable

  #
  # delegate highline methods to make them available to sub-commands
  #
  @terminal = HighLine.new
  def_delegator :@terminal, :ask,    'self.ask'
  def_delegator :@terminal, :agree,  'self.agree'
  def_delegator :@terminal, :choose, 'self.choose'
  def_delegator :@terminal, :say,    'self.say'
  def_delegator :@terminal, :color,  'self.color'
  def_delegator :@terminal, :list,   'self.list'

  #
  # make config manager available as 'manager'
  #
  def self.manager
    @manager ||= begin
      manager = LeapCli::Config::Manager.new
      manager.load
      manager
    end
  end

  #
  # info about leap command line suite
  #
  program_desc       LeapCli::SUMMARY
  program_long_desc  LeapCli::DESCRIPTION

  #
  # handle --version ourselves
  #
  if ARGV.grep(/--version/).any?
    puts "leap #{LeapCli::VERSION}, ruby #{RUBY_VERSION}"
    exit(0)
  end

  #
  # load commands and run
  #
  commands_from('leap_cli/commands')
end
