require 'spec_helper'

class Foo < ActiveRecord::Base; end

module Authorizations
  class FooAuthorizations
    def self.record_attrs(foo)
      [
        { bar_id: foo.bar_id },
        { taco_id: foo.taco_id }
      ]
    end

    def initialize(user)
      @user = user
    end

    def bazify
      [
        { bar_id: user.bar_id },
        { taco_id: user.taco_id }
      ]
    end

    private

    attr_reader :user
  end
end

describe "acceptance specs" do
  before :all do
    ActiveRecord::Migration.suppress_messages do
      ActiveRecord::Migration.create_table :foos, temporary: true do |t|
        t.integer :bar_id
        t.integer :taco_id
      end
    end
  end

  after :all do
    ActiveRecord::Migration.suppress_messages do
      ActiveRecord::Migration.drop_table :foos
    end
  end

  let(:user) { double(:user, bar_id: 1, taco_id: 2) }

  def make_authorized_foo
    foo = Foo.create(bar_id: 1, taco_id: 999)
    AuthorizationAttrs.reset_attrs_for(foo)
    foo
  end

  def make_unauthorized_foo
    foo = Foo.create(bar_id: 999, taco_id: 999)
    AuthorizationAttrs.reset_attrs_for(foo)
    foo
  end

  describe "querying authorizations" do
    context "when a single record is queried" do
      it 'should return true if one of the attributes overlap' do
        expect(AuthorizationAttrs.authorized?(:bazify, Foo, make_authorized_foo, user)).to eq true
      end

      it 'can be called with an id' do
        expect(AuthorizationAttrs.authorized?(:bazify, Foo, make_authorized_foo.id, user)).to eq true
      end

      it 'should return false if none of the attributes overlap' do
        expect(AuthorizationAttrs.authorized?(:bazify, Foo, make_unauthorized_foo, user)).to eq false
      end
    end

    context "when multiple records are queried" do
      it 'should return false if all of the records are unauthorized' do
        expect(AuthorizationAttrs.authorized?(:bazify, Foo, [make_unauthorized_foo, make_unauthorized_foo], user))
          .to eq false
      end

      it 'should return false if any of the records are unauthorized' do
        expect(AuthorizationAttrs.authorized?(:bazify, Foo, [make_authorized_foo, make_unauthorized_foo], user))
          .to eq false
      end

      it 'should return true if all of the records are authorized' do
        expect(AuthorizationAttrs.authorized?(:bazify, Foo, [make_authorized_foo, make_authorized_foo], user))
          .to eq true
      end
    end
  end

  describe "finding records by permission" do
    it "should return an empty array if no records match" do
      first_foo, second_foo = make_unauthorized_foo, make_unauthorized_foo

      found_records = AuthorizationAttrs.find_by_permission(:bazify, Foo, user)

      expect(found_records).to eq []
    end

    it "should return only records that match" do
      first_foo, second_foo, third_foo = make_unauthorized_foo, make_authorized_foo, make_unauthorized_foo

      found_records = AuthorizationAttrs.find_by_permission(:bazify, Foo, user)

      expect(found_records).to eq [second_foo]
    end
  end
end
