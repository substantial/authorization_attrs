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

## Why another framework?

There are two primary reasons to use an authorization framework like this.

1. You need to search via permission either directly or else in a separate
   service such as a search engine and don't want to duplicate your
   authorizations logic. Avoiding such duplications and rewrites will improve
   both code quality and your personal efficiency. 
2. You think that such searches are likely to be required as your application
   grows and want to maintain that flexibility.

Reasons not to use this:

1. Using a separate table for authorizations incurs a performance penalty for
   most authorizations on single records, which is a common use case. Since this is
   a penalty relative to what is usually a fast operation, this may or may not be
   relevant to your application. Check the benchmarks and your own application's
   bottlenecks to see if this trade-off is acceptable to you.
2. Additional (though minimal) maintenance is required to keep your authorizations
   table up to date.

AuthorizationAttrs can easily exist alongside other authorization frameworks,
so use as little or as much of it as you want.

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

This logic will work, but is less extensible because it defines a single method
of comparison between two objects. If instead we define the *relationships* between 
users and groups in general, it would be possible to write any comparison we want. 

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
with authorizations by placing a `#{Model}Authorizations` class within your
autoload path.

```ruby
class Authorizations::ArticleAuthorizations
  # .record_attrs declares how Article instances should generate their own
  # list of authorization attributes. Each type of attribute must exist on the
  # records in order for them to be queried against.

  def self.record_attrs(article)
    [
      { public: article.public? },
      { author_id: article.author_id }
    ]
  end

  # This class is instantiated with a user when user attributes are retrieved.

  def initialize(user)
    @user = user
  end

  # Define your permission logic:

  def edit
    # Admins can edit all articles.

    return :all if user.admin?

    # Other users can edit public articles or articles they authored.

    [
      { public: true },
      { author_id: user.id }
    ]
  end

  private

  attr_reader :user
end
```

This logic is record-agnostic and as such can be applied to one, many, or all
records.

To test authorizations:

```ruby
# returns true if authorized
AuthorizedAttrs.authorized?(:edit, Article, article_id, user)

# returns true only if all records are authorized
AuthorizedAttrs.authorized?(:edit, Article, array_of_article_ids, user)

# raises error if authorization returns false
AuthorizationAttrs.authorize!(:edit, Article, article_id, user)
```

ActiveRecord model instances will also work in place of ids.

To search by permission:

```ruby
AuthorizationAttrs.find_by_authorization(:edit, Article, user)
```

In order to use searching by permission, add the following relation to your
model:

```ruby
has_many :authorization_attrs, as: :authorizable
```

Some of this functionality may be attainable through cleverly written SQL
queries, removing the need for a separate table of authorization attributes.
The drawback to such an approach is that they may not be reusable for all
cases, query logic can quickly get out of hand while consuming developer time,
and such an approach would not allow exporting these authorizations into a
separate service such as a search engine.

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

## Setup

Add the gem to your project's Gemfile:

```ruby
gem 'authorization_attrs'
```

AuthorizationAttrs requires a database table and (currently) an ActiveRecord model to
function. A Rails generator is available to make these for you. 

```
$ rails generate authorization_attrs:setup
```

Since this authorization framework is dependent upon a separate table,
attributes must be initialized at the start and recalculated whenever they 
could be changed. Use the following method to update your authorization
attributes:

```ruby
AuthorizationAttrs.reset_attrs_for(self)
```

## Benchmarks

Benchmarks are available to help identify weaknesses in the code base and help
developers make decisions about where this framework may be helpful. Run them
with:

```
$ rake benchmarks
```

General summaries of current benchmarks: 

- Since authorizations are done as a full SQL query, they cannot terminate early
  once the query begins. It also means that they are subject to less variance
  in performance than typical direct comparisons.
- Checking permissions on a single record is typically slower than equivalent direct 
  comparisons.
- Testing on multiple records is approximately as fast as testing a single
  record. Compared to equivalent iterative direct comparisons, this tends to be
  faster the more records are being evaluated, especially when all evaluate to
  true (which should be the case for a well-designed UI).
- Searching by permission is faster than authorizing a single record.
  An equivalent iterative direct comparison is entirely unfeasible and could
  only be rendered feasible by duplicating authorization logic in a separate
  query.

Pull requests to add more benchmarks are welcomed. 

## Extensions

The other strong advantage of this approach is that it is easily extensible to
additional systems on top of ActiveRecord. A search
engine can index these fields, giving instant support for searching by
permission without having to rewrite business logic.

For an example of such extensions, consider the following
implementation for Sunspot:

```ruby
class Organization
  searchable do
    string :authorization_attrs, multiple: true do
      AuthorizationAttr.where(authorizable: self).pluck(:name)
    end
  end
end

def apply_permission_to_search(search, permission, model, user)
  user_attrs = AuthorizationAttrs.user_attrs(permission, model, user)

  return if user_attrs == :all

  serialized_attrs = AuthorizationAttrs::ActiveRecordStorageStrategy.serialize_attrs(user_attrs)

  search.with(:authorization_attrs, serialized_attrs)
end

Organization.search do |search|
  apply_permission_to_search(search, :view, Organization, current_user)
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

## Contributing

1. Fork it ( https://github.com/[my-github-username]/authorization_attrs/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Ensure all existent tests are passing and any new feature has test coverage
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
