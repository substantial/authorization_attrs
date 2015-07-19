require "authorization_attrs/version"

module AuthorizationAttrs
  def self.authorized?(permission, record, user)
    user_attrs = user_attrs(permission, record.class, user)

    return true if user_attrs == :all
    return false if user_attrs == []

    storage_strategy.authorizations_match?(record: record, user_attrs: user_attrs)
  end

  def self.user_attrs(permission, klass, user)
    finder.user_attrs_class(klass).new(user).public_send(permission)
  end

  def self.model_attrs(record)
    finder.model_attrs_class(record.class).model_attrs(record)
  end

  def self.reset_attrs_for(record)
    storage_strategy.reset_attrs_for(record, new_record_attrs: model_attrs(record))
  end

  def self.storage_strategy
    SqlDataStore
  end

  def self.finder
    DefaultFinder
  end
end
