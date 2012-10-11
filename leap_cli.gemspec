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
  s.author = 'LEAP'
  s.email = 'root@leap.se'
  s.homepage = 'https://leap.se'
  s.platform = Gem::Platform::RUBY
  s.summary = 'Command line interface to the leap platform.'

  ##
  ## GEM FILES
  ##
  s.files = `find lib -name '*.rb'`.split("\n") << "bin/leap"
  s.require_paths << 'lib'

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
  #s.add_development_dependency('rdoc')
  #s.add_development_dependency('aruba')

  s.add_runtime_dependency('gli','~> 2.3')
  s.add_runtime_dependency('json_pure')
  s.add_runtime_dependency('terminal-table')
  s.add_runtime_dependency('highline')
end
