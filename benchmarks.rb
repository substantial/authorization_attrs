require 'benchmark'
require './benchmarks/authorization_benchmarks.rb'

module Benchmarks
  def self.execute
    AuthorizationBenchmarks.execute
  end
end
