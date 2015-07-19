# AuthorizationAttrs

This is a light authorization library designed to permit searching by
permission, rather than only checking permissions on specific objects.

AuthorizationAttrs functions by associating records with a destructured list of
relevant authorization attributes related to that model. When a
user is evaluated in a permission, a list of record attributes which
would allow the action are generated for that user. The permission
evaluates to true if there is intersection between the user's attributes for that
permission and the record's attributes. By preloading these approved
attributes for each user and storing the records's attributes, we gain
the ability to easily search by permission in a database or search engine.

For example, say a group is editable by:

  Its admins
  Its organization's admins
  Cms admins

If we flip this around and define which groups a user can edit, they are:

  Groups the user is an admin of (group ids)
  All groups in all organizations they are admins of (organization ids)
  All groups if they are a cms admin (:all)

In order to determine if a group fits the bill, we must know:

  The group's id
  The group's organization id

These are the authorization attributes stored by each group.

To check a permission on an individual record or set of records, we simply compare
attributes. If a group has as attributes:

  organization_id=3
  group_id=22

and a user who is an appropriate org admin but not the correct group admin is given as
attributes for the edit permission:

  organization_id=3
  group_id=49
  group_id=93

There will be overlap on organization_id=3, and the permission will pass.

For a more concrete example, here would be the above permission as written in Cancan:

can :edit, Group do |group|
  user.cms_admin? ||
    GroupUser.where(user: user, group: group, admin: true).any? ||
    OrganizationUser.where(user: user, organization: group.organization, admin: true).any?
end

This logic will work, but locks us into the need for a specific record to test against.

The following code can be written instead (this module is automatically associated
with the Group model by being named GroupAuthorizations):

module GroupAuthorizations
  # #model_attrs declares how Group instances should generate their own
  # list of authorization attributes. Once these attributes are declared, they
  # never need to be changed unless new attributes are being added.

  def self.model_attrs(group)
    [
      { group_id: group.id },
      { organization_id: group.organization_id }
    ]
  end

  class UserAuthorizationAttrs
    def initialize(user)
      @user = user
    end

    # Both #model_attrs and these permissions returning user attributes must return
    # an array of hashes. Each hash represents a single authorization attribute which
    # would be sufficent to authorize the permission for a given record.
    # Hashes with more than a single entry represent compound attributes such as
    # needing to be both a member of a post's containing group and the owner of
    # a post (serialized as "group_id=#{post.group_id}&owner_id=#{post.owner_id}"

    def edit
      return :all if user.cms_admin?

      admined_group_ids.map { |id| { group_id: id } } +
        admined_org_ids.map { |id| { organization_id: id } }
    end

    private

    attr_reader :user

    def admined_group_ids
      GroupUser.where(user: user, admin: true).pluck(:group_id)
    end

    def admined_org_ids
      OrganizationUser.where(
        user: user,
        organization_admin: true
      ).pluck(:organization_id)
    end
  end
end

This logic is more broadly phrased and can now be applied in a record-agnostic
fashion.

To test on an individual record:

AuthorizedAttrs.authorized?(:edit, group, user)

OPTIONS:

You may find that comparing attributes is unnecessary if user-centric attributes
can completely resolve the permission. In these cases, return :all or an empty
array (no permissions for that user) from the permission. Nil will also be
interpreted as an empty array.

module PostAuthorizations
  class UserAuthorizationAttrs
    def delete
      return :all if user.cms_admin?
    end
  end
end


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'authorization_attrs'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install authorization_attrs

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

1. Fork it ( https://github.com/[my-github-username]/authorization_attrs/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
