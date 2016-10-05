module LeapCli
  module Commands; end  # for commands in leap_platform/lib/leap_cli/commands
  module Macro; end     # for macros in leap_platform/lib/leap_cli/macros
end

$ruby_version = RUBY_VERSION.split('.').collect{ |i| i.to_i }.extend(Comparable)

# ensure lib/leap_cli/overrides has the highest priority
$:.unshift(File.expand_path('../leap_cli/override',__FILE__))

# for a few gems, things will break if using earlier versions.
# enforce the compatible versions here:
require 'rubygems'
gem 'gli', '~> 2.12', '>= 2.12.0'

require 'leap_cli/version'
require 'leap_cli/exceptions'

require 'leap_cli/leapfile'
require 'leap_cli/core_ext/boolean'
require 'leap_cli/core_ext/deep_dup'
require 'leap_cli/core_ext/hash'
require 'leap_cli/core_ext/json'
require 'leap_cli/core_ext/nil'
require 'leap_cli/core_ext/string'
require 'leap_cli/core_ext/time'
require 'leap_cli/core_ext/yaml'

require 'leap_cli/log'
require 'leap_cli/path'
require 'leap_cli/util'
require 'leap_cli/bootstrap'

require 'leap_cli/markdown_document_listener'

#
# allow everyone easy access to log() command.
#
module LeapCli
  extend LeapCli::LogCommand
end
