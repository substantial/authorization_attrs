class CreateAuthorizationKeys < ActiveRecord::Migration
  def change
    create_table :authorization_attrs do |t|
      t.string :name
      t.references :authorizable, polymorphic: true
    end

    add_index :authorization_attrs, [:authorizable_type, :authorizable_id, :name],
      name: "index_on_authorizable_and_name",
      unique: true
  end
end
