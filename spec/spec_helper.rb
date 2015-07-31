$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'authorization_attrs'
require 'rspec/active_model/mocks'
require 'database_cleaner'
require 'pry'

require './spec/support/setup_authorization_attrs_table.rb'

RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end

