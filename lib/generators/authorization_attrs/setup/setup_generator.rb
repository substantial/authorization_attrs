require 'rails/generators'

module AuthorizationAttrs
  module Generators
    class SetupGenerator < Rails::Generators::Base
      source_root File.expand_path("../templates", __FILE__)

      desc "Generates the appropriate model to use authorization_attrs"

      def setup_model
        copy_file "authorization_attr.rb", "app/models/authorization_attr.rb"
      end
    end
  end
end
