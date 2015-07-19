module AuthorizationAttrs
  module DefaultFinder
    def self.user_attrs_class(klass)
      "Authorizations::#{klass}Authorizations::UserAuthorizationAttrs".constantize
    end

    def self.model_attrs_class(klass)
      "Authorizations::#{klass}Authorizations".constantize
    end
  end
end
