module AuthorizationAttrs
  module DefaultFinder
    def self.user_attrs_class(klass)
      "Authorizations::#{klass}Authorizations".constantize
    end

    def self.record_attrs_class(klass)
      "Authorizations::#{klass}Authorizations".constantize
    end
  end
end
