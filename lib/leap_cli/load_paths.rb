#
# Bundle and rubygems each have their own way of modifying $LOAD_PATH.
#
# We want to make sure that the right paths are loaded, including the
# vendored gems, regardless of how leap is run.
#
#

require File.expand_path('../version', __FILE__)

base_leap_dir = File.expand_path('../../..', __FILE__)
LeapCli::LOAD_PATHS.each do |path|
  path = File.expand_path(path, base_leap_dir)
  $LOAD_PATH.unshift(path) unless $LOAD_PATH.include?(path)
end