# AuthorizationAttrs

This is a light authorization library designed to permit searching by
permission, rather than only checking permissions on instances of models.

AuthorizationAttrs functions by associating records with a destructured list of
authorization attributes relevant to that model. When a
user is evaluated in a permission, a list of record attributes which
would allow the action are generated for that user. The permission
evaluates to true if there is intersection between the user's attributes for that
permission and the record's attributes. By preloading these approved
attributes for each user and storing the records's attributes, we gain
the ability to easily search by permission in a database or search engine.

## Example

Say you're working on an application with organizations and groups within them.
The users permitted to edit a group might be the following:

* Its admins
* Its organization's admins
* Super admins

Here would be the above permission as written in most authorization frameworks:

```ruby
def can_edit?(user, group)
  user.super_admin? ||
    GroupUser.where(user: user, group: group, admin: true).any? ||
    OrganizationUser.where(user: user, organization: group.organization, admin: true).any?
end
```

This logic will work, but locks us into the need for a specific record to test against.

If we flip the logic around and define which groups a given user can edit, they are:

*  Groups the user is an admin of
*  All groups in all organizations they are admins of
*  All groups if they are a super admin

In order to determine if a group fits the authorization criteria for a user, we must know:

*  The group's id
*  The group's organization id

These are the authorization attributes stored by each group. Note that we don't
store any reference to super admin status since that has nothing to do with any
instance of a group. 

To check a permission on an individual record or set of records, we compare
attributes. If a group has as attributes:

*  `group_id=22`
*  `organization_id=3`

and a user who is an appropriate org admin but not the correct group admin is given the
following attributes for the edit permission:

*  `group_id=49`
*  `organization_id=3`

There will be overlap on `organization_id=3`, and the permission will pass. Of
course, if the user is a super admin, we can pass the permission without
comparing any attributes. 

## Usage

To use authorization_attrs, you can automatically associate each of your models
with authorizations by placing a `#{Model}Authorizations` module under
`app/models/authorizations`.

```ruby app/models/authorizations
module GroupAuthorizations
  # .record_attrs declares how Group instances should generate their own
  # list of authorization attributes. Once these attributes are declared, they
  # never need to be changed unless new attributes are being added.

  def self.record_attrs(group)
    [
      { group_id: group.id },
      { organization_id: group.organization_id }
    ]
  end

  def initialize(user)
    @user = user
  end

  # Define your permission logic:

  def edit
    return :all if user.super_admin?

    [admined_by_user, in_org_admined_by_user].flatten
  end

  private

  attr_reader :user

  def admined_by_user
    admined_group_ids.map { |id| { group_id: id } }
  end

  def in_org_admined_by_user
    admined_org_ids.map { |id| { organization_id: id } }
  end

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
```

This logic is more broadly phrased and can now be applied in a record-agnostic
fashion.

To test authorizations:

```ruby
# returns true if authorized
AuthorizedAttrs.authorized?(:edit, Group, group_id, user)

# returns true only if all records are authorized
AuthorizedAttrs.authorized?(:edit, Group, [group_ids], user)
```

To search on permission:

```ruby
AuthorizationAttrs.find_by_authorization(:edit, Group, user)
```

## Setup

AuthorizationAttrs requires a database table and ActiveRecord model to
function. A Rails generator is available to set these up. 

```
rails generate authorization_attrs:setup
```

Since this authorization framework is dependent upon a separate table,
attributes must be initialized at the start and recalculated whenever they 
could be changed. Use the following method to update your authorization
attributes:

```ruby
AuthorizationAttrs.reset_attrs_for(self)
```

## Attribute Format

Each of the methods defining model or user attributes must output an array of
hashes. Each hash represents a single authorization attribute which
would be sufficient to authorize the permission for a given record.

Hashes with more than a single key/value pair represent compound attributes such as
needing to be both a member of a post's containing group and the owner of
a post (key order is irrelevant):

```ruby
{ group_id: post.group.id, id: post.owner.id }
```

You may find that comparing attributes is unnecessary if user-centric attributes
can completely resolve the permission. In these cases, return `:all` to grant
universal access for that permission or an empty array to deny access. 
Nil will also be interpreted as denying access. 

```ruby
module PostAuthorizations
  def delete
    return :all if user.super_admin?
  end
end
```

## Tips

### Reseting attributes

Authorization attributes should almost always be composed from attributes of
the model itself. As such, `after_save` hooks are usually safe and reasonable
solutions. 

```ruby
after_save :reset_authorization_attrs

def reset_authorization_attrs
  AuthorizationAttrs.reset_attrs_for(self)
end
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'authorization_attrs'
```

And then execute:

```
$ bundle
```


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

1. Fork it ( https://github.com/[my-github-username]/authorization_attrs/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Ensure all existent tests are passing and any new feature has test coverage
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
