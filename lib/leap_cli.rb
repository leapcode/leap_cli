module LeapCli; end

unless defined?(LeapCli::VERSION)
  # ^^ I am not sure why this is needed.
  require 'leap_cli/version.rb'
end

require 'core_ext/hash'
require 'core_ext/boolean'
require 'core_ext/nil'

require 'leap_cli/init'
require 'leap_cli/path'
require 'leap_cli/log'
require 'leap_cli/config/object'
require 'leap_cli/config/object_list'
require 'leap_cli/config/manager'


#
# make 1.8 act like ruby 1.9
#
unless String.method_defined?(:to_a)
  class String
    def to_a; [self]; end
  end
end
