require 'authorization_attrs/retry'

module AuthorizationAttrs
  class SqlDataStore
    include Retry

    def self.authorizations_match?(record:, user_attrs:)
      AuthorizationAttr.where(
        authorizable: record,
        name: serialize_attrs(user_attrs)
      ).any?
    end

    def self.reset_attrs_for(record, new_record_attrs:)
      current_attrs = AuthorizationAttr.where(authorizable: record).pluck(:name)
      new_attrs = serialize_attrs(new_record_attrs)

      with_retry(exception: ActiveRecord::RecordNotUnique) do
        ActiveRecord::Base.transaction do
          AuthorizationAttr.where(
            authorizable: record,
            name: current_attrs - new_attrs
          ).delete_all

          (new_attrs - current_attrs).each do |attr|
            AuthorizationAttr.create(authorizable: record, name: attr)
          end
        end
      end
    end

    def self.serialize_attrs(data)
      if data.is_a? Hash
        raise ArgumentError,
          "Please supply an array of hashes representing authorization attributes"
      end

      data = Array(data).compact

      data.map do |attrs_hash|
        attrs_hash.sort.map { |attr, value| "#{attr}=#{value}" }.join("&")
      end
    end
  end
end
