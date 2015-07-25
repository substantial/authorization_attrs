$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'authorization_attrs'
require 'active_record'
require 'rspec/active_model/mocks'

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')

class AuthorizationAttr < ActiveRecord::Base
  belongs_to :authorizable, polymorphic: true
end

ActiveRecord::Migration.suppress_messages do
  ActiveRecord::Migration.create_table "authorization_attrs" do |t|
    t.string  :name
    t.references :authorizable, polymorphic: true
  end

  ActiveRecord::Migration.add_index(
    "authorization_attrs",
    ["authorizable_type", "authorizable_id", "name"],
    name: "index_on_authorizable_and_name",
    unique: true
  )
end

