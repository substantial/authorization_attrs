module AuthorizationAttrs
  module DefaultFinder
    def self.authorizations_class(klass)
      "Authorizations::#{klass}Authorizations".constantize
    end
  end
end
