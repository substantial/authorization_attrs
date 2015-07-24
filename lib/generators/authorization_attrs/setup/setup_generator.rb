require 'rails/generators'

module AuthorizationAttrs
  module Generators
    class SetupGenerator < Rails::Generators::Base
      source_root File.expand_path("../templates", __FILE__)

      desc "Generates the appropriate model to use authorization_attrs"

      def setup_model
        timestamp = Time.now.strftime("%Y%m%d%H%M%S")

        copy_file "authorization_attr.rb", "app/models/authorization_attr.rb"
        copy_file "authorization_attr_migration.rb", "db/migrate/#{timestamp}_add_authorization_attrs_table.rb"
      end
    end
  end
end
