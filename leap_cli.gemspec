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
  s.license = "MIT"

  ##
  ## GEM FILES
  ##

  s.files = `find lib -name '*.rb'`.split("\n")
  s.files += ["bin/leap"]
  s.files += `find vendor -name '*.rb'`.split("\n")
  s.files += `find vendor/vagrant_ssh_keys -name '*.pub' -o -name '*.key'`.split("\n")
  s.require_paths += LeapCli::LOAD_PATHS
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

  # test
  s.add_development_dependency('minitest', '~> 5.0')

  #s.add_development_dependency('rdoc')
  #s.add_development_dependency('aruba')

  # console gems
  s.add_runtime_dependency('gli','~> 2.12', '>= 2.12.0')
  # note: gli version is also pinned in leap_cli.rb.
  s.add_runtime_dependency('command_line_reporter', '~> 3.3')
  s.add_runtime_dependency('highline', '~> 1.6')
  s.add_runtime_dependency('paint', '~> 0.9')

  # network gems
  s.add_runtime_dependency('net-ssh', '~> 2.7.0')
  # ^^ we can upgrade once we get off broken capistrano
  # https://github.com/net-ssh/net-ssh/issues/145
  s.add_runtime_dependency('capistrano', '~> 2.15.5')

  # crypto gems
  #s.add_runtime_dependency('certificate_authority', '>= 0.2.0')
  # ^^ currently vendored
  # s.add_runtime_dependency('gpgme')    # << does not build on debian jessie, so now optional.
                                         # also, there is a ruby-gpgme package anyway.

  # misc gems
  s.add_runtime_dependency('ya2yaml', '~> 0.31')    # pure ruby yaml, so we can better control output. see https://github.com/afunai/ya2yaml
  s.add_runtime_dependency('json_pure', '~> 1.8')   # pure ruby json, so we can better control output.
  s.add_runtime_dependency('base32', '~> 0.3')      # base32 encoding

  ##
  ## DEPENDENCIES for VENDORED GEMS
  ##

  # certificate_authority
  s.add_runtime_dependency("activemodel", ">= 3.0.6")
end
