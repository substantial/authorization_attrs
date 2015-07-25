require "authorization_attrs/version"
require "authorization_attrs/sql_data_store"
require "authorization_attrs/default_finder"
require "authorization_attrs/ids_filter"

module AuthorizationAttrs
  def self.authorized?(permission, model, record, user)
    record_id = IdsFilter.filter(record)

    user_attrs = user_attrs(permission, record.class, user)

    return true if user_attrs == :all
    return false if user_attrs == []

    storage_strategy.authorizations_match?(
      model: model,
      record_id: record_id,
      user_attrs: user_attrs
    )
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
