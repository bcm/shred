# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'shred/version'

Gem::Specification.new do |spec|
  spec.name          = 'shred'
  spec.version       = Shred::VERSION
  spec.authors       = %w(Brian Moseley)
  spec.email         = %w(bcm@maz.org)
  spec.summary       = 'Opinionated Ruby task runner'
  spec.description   = 'A task runner written in Ruby that does exactly what I want, how I want it'
  spec.homepage      = 'http://github.com/bcm/shred'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = %w(lib)

  spec.add_development_dependency 'bundler', '~> 1.7'
  spec.add_development_dependency 'rake',    '~> 10.0'

  spec.add_dependency 'aws-sdk-v1',    '~> 1.61'
  spec.add_dependency 'dotenv',        '~> 1.0'
  spec.add_dependency 'elasticsearch', '~> 1.0'
  spec.add_dependency 'platform-api',  '~> 0.2'
  spec.add_dependency 'thor',          '~> 0.19'
end
