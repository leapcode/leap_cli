#
# Ensure we require the local version and not one we might have installed already
#
require File.join([File.dirname(__FILE__),'lib','leap_cli','version.rb'])

spec = Gem::Specification.new do |s|

  ##
  ## ABOUT THIS GEM
  ##
  s.name = 'leap_cli'
  s.version = LeapCli::VERSION
  s.author = 'LEAP Encryption Access Project'
  s.email = 'root@leap.se'
  s.homepage = 'https://leap.se'
  s.platform = Gem::Platform::RUBY
  s.summary = LeapCli::SUMMARY
  s.description = LeapCli::DESCRIPTION
  s.license = "GPLv3"

  ##
  ## GEM FILES
  ##

  s.files = `find lib vendor -name '*.rb'`.split("\n") << "bin/leap"
  s.require_paths += LeapCli::REQUIRE_PATHS

  s.bindir = 'bin'
  s.executables << 'leap'

  ##
  ## DOCUMENTATION
  ##
  #s.has_rdoc = true
  #s.extra_rdoc_files = ['README.rdoc','leap_cli.rdoc']
  #s.rdoc_options << '--title' << 'leap_cli' << '--main' << 'README.rdoc' << '-ri'

  ##
  ## DEPENDENCIES
  ##
  s.add_development_dependency('rake')
  s.add_development_dependency('minitest')
  #s.add_development_dependency('rdoc')
  #s.add_development_dependency('aruba')

  # console gems
  s.add_runtime_dependency('gli','~> 2.3')
  s.add_runtime_dependency('terminal-table')
  s.add_runtime_dependency('highline')
  s.add_runtime_dependency('paint')

  # network gems
  s.add_runtime_dependency('capistrano')
  #s.add_runtime_dependency('supply_drop')

  # crypto gems
  s.add_runtime_dependency('certificate_authority') # this gem pulls in ActiveModel, but it just uses it for validation logic.
  s.add_runtime_dependency('net-ssh')
  s.add_runtime_dependency('gpgme')     # not essential, but used for some minor stuff in adding sysadmins

  # misc gems
  s.add_runtime_dependency('ya2yaml')   # pure ruby yaml, so we can better control output. see https://github.com/afunai/ya2yaml
  s.add_runtime_dependency('json_pure') # pure ruby json, so we can better control output.

end
