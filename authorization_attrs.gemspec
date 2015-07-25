# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'authorization_attrs/version'

Gem::Specification.new do |spec|
  spec.name          = "authorization_attrs"
  spec.version       = AuthorizationAttrs::VERSION
  spec.authors       = ["Derek Maffett"]
  spec.email         = ["derek@substantial.com"]

  spec.summary       = %q{Authorization framework}
  spec.description   = %q{An authorization framework to permit searching by permission}
  spec.homepage      = "TODO: Put your gem's website or public repo URL here."
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com' to prevent pushes to rubygems.org, or delete to allow pushes to any server."
  end

  spec.add_development_dependency "bundler", "~> 1.8"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.3"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "database_cleaner"
  spec.add_development_dependency "activerecord", "~> 4.2"
  spec.add_development_dependency "sqlite3", "~> 1.3.10"
  spec.add_development_dependency "rspec-activemodel-mocks"
end
