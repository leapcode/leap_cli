module LeapCli; end

unless defined?(LeapCli::VERSION)
  # ^^ I am not sure why this is needed.
  require 'leap_cli/version.rb'
end

require 'leap_cli/init'
require 'leap_cli/path'
require 'leap_cli/log'
require 'leap_cli/config'
require 'leap_cli/config_list'
require 'leap_cli/config_manager'

unless String.method_defined?(:to_a)
  class String
    def to_a; [self]; end
  end
end