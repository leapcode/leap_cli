module LeapCli; end

require 'leap_cli/version.rb'
require 'leap_cli/requirements.rb'
require 'core_ext/hash'
require 'core_ext/boolean'
require 'core_ext/nil'

require 'leap_cli/log'
require 'leap_cli/init'
require 'leap_cli/path'
require 'leap_cli/util'
require 'leap_cli/util/secret'
require 'leap_cli/util/remote_command'
require 'leap_cli/util/x509'

require 'leap_cli/remote/log_streamer'
require 'leap_cli/logger'

require 'leap_cli/ssh_key'
require 'leap_cli/config/object'
require 'leap_cli/config/object_list'
require 'leap_cli/config/manager'

module LeapCli::Commands; end

module LeapCli
  Util.send(:extend, LeapCli::Log)
  Commands.send(:extend, LeapCli::Log)
  Config::Manager.send(:include, LeapCli::Log)
  extend LeapCli::Log
end

#
# make ruby 1.9 act more like ruby 1.8
#
unless String.method_defined?(:to_a)
  class String
    def to_a; [self]; end
  end
end

unless String.method_defined?(:any?)
  class String
    def any?; self.chars.any?; end
  end
end

