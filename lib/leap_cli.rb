module LeapCli; end

require 'leap_cli/version.rb'
require 'core_ext/hash'
require 'core_ext/boolean'
require 'core_ext/nil'

require 'leap_cli/init'
require 'leap_cli/path'
require 'leap_cli/util'
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

unless String.method_defined?(:any?)
  class String
    def any?; self.chars.any?; end
  end
end

