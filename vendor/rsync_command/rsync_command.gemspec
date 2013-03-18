# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rsync_command/version'

Gem::Specification.new do |spec|
  spec.name          = "rsync_command"
  spec.version       = RsyncCommand::VERSION
  spec.authors       = ["elijah"]
  spec.email         = ["elijah@leap.se"]
  spec.description   = %q{A library wrapper for the the rsync command.}
  spec.summary       = %q{Includes support for Net::SSH-like configuration and asynchronous execution.}
  spec.homepage      = "https://github.com/leapcode/rsync_command"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
