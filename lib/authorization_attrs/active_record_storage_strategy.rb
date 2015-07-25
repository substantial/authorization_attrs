require 'authorization_attrs/retry'

module AuthorizationAttrs
  class ActiveRecordStorageStrategy
    include Retry

    def self.authorizations_match?(model:, record_ids:, user_attrs:)
      AuthorizationAttr.where(
        authorizable_type: model,
        authorizable_id: record_ids,
        name: serialize_attrs(user_attrs)
      ).pluck(:authorizable_id).uniq.count == record_ids.size
    end

    def self.find_by_permission(model:, user_attrs:)
      association = model.reflect_on_association(:authorization_attrs)

      unless association && association.options[:as] == :authorizable
        raise "Please add the following to #{model} to use this feature:\n\n has_many :authorization_attrs, as: :authorizable"
      end

      return model.all if user_attrs == :all

      model.joins(:authorization_attrs).where(
        authorization_attrs: {
          authorizable_type: model,
          name: serialize_attrs(user_attrs)
        }
      )
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
