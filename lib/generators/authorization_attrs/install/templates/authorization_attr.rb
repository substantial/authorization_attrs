class AuthorizationAttr < ActiveRecord::Base
  belongs_to :authorizable, polymorphic: true
end
