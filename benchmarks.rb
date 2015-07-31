require 'benchmark'
require './benchmarks/single_record_authorization_benchmarks.rb'
require './spec/support/setup_authorization_attrs_table.rb'

module Benchmarks
  def self.execute
    SingleRecordAuthorizationBenchmarks.execute
  end
end
