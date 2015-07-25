require "authorization_attrs/version"
require "authorization_attrs/sql_data_store"
require "authorization_attrs/default_finder"
require "authorization_attrs/ids_filter"

module AuthorizationAttrs
  def self.authorized?(permission, model, records, user)
    record_ids = IdsFilter.filter(records)

    user_attrs = user_attrs(permission, model, user)

    return true if user_attrs == :all
    return false if user_attrs == []

    storage_strategy.authorizations_match?(
      model: model,
      record_ids: record_ids,
      user_attrs: user_attrs
    )
  end

  def self.user_attrs(permission, model, user)
    finder.authorizations_class(model).new(user).public_send(permission)
  end

  def self.record_attrs(record)
    finder.authorizations_class(record.class).record_attrs(record)
  end

  def self.reset_attrs_for(record)
    storage_strategy.reset_attrs_for(record, new_record_attrs: record_attrs(record))
  end

  def self.storage_strategy
    SqlDataStore
  end

  def self.finder
    DefaultFinder
  end
end
