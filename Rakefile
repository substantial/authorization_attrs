require "bundler/gem_tasks"

begin
  require 'rspec/core/rake_task'

  RSpec::Core::RakeTask.new(:spec)

  task :default => :spec
rescue LoadError
end

task :benchmarks do
  require './benchmarks/authorization_attrs_benchmarks.rb'

  AuthorizationAttrsBenchmarks.execute
end
