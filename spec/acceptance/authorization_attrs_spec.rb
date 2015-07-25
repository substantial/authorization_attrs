require 'spec_helper'

class Foo < ActiveRecord::Base; end

module Authorizations
  module FooAuthorizations
    def self.record_attrs(foo)
      [
        { bar_id: foo.bar_id },
        { taco_id: foo.taco_id }
      ]
    end

    class UserAuthorizationAttrs
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

  context "when a single record is queried" do
    let(:user) { double(:user, bar_id: 1, taco_id: 999) }
    let(:foo) { Foo.create(bar_id: 1, taco_id: 2) }

    it 'should return true if one of the attributes overlap' do
      AuthorizationAttrs.reset_attrs_for(foo)

      authorized = AuthorizationAttrs.authorized?(:bazify, Foo, foo.id, user)

      expect(authorized).to eq true
    end

    it 'can be called with a record' do
      AuthorizationAttrs.reset_attrs_for(foo)

      authorized = AuthorizationAttrs.authorized?(:bazify, Foo, foo, user)

      expect(authorized).to eq true
    end

    it 'should return false if none of the attributes overlap' do
      allow(user).to receive(:bar_id) { "nope" }
      allow(user).to receive(:taco_id) { "nope" }
      AuthorizationAttrs.reset_attrs_for(foo)

      authorized = AuthorizationAttrs.authorized?(:bazify, Foo, foo.id, user)

      expect(authorized).to eq false
    end
  end

  context "when multiple records are queried" do
    it 'should return false if all of the records are unauthorized' do
      first_foo = Foo.create(bar_id: 999, taco_id: 999)
      second_foo = Foo.create(bar_id: 999, taco_id: 999)
      user = double(:user, bar_id: 1, taco_id: 50)

      AuthorizationAttrs.reset_attrs_for(first_foo)
      AuthorizationAttrs.reset_attrs_for(second_foo)

      expect(AuthorizationAttrs.authorized?(:bazify, Foo, first_foo, user)).to eq false
      expect(AuthorizationAttrs.authorized?(:bazify, Foo, second_foo, user)).to eq false

      expect(AuthorizationAttrs.authorized?(:bazify, Foo, [first_foo, second_foo], user))
        .to eq false
    end

    it 'should return false if any of the records are unauthorized' do
      first_foo = Foo.create(bar_id: 1, taco_id: 2)
      second_foo = Foo.create(bar_id: 999, taco_id: 999)
      user = double(:user, bar_id: 1, taco_id: 50)

      AuthorizationAttrs.reset_attrs_for(first_foo)
      AuthorizationAttrs.reset_attrs_for(second_foo)

      expect(AuthorizationAttrs.authorized?(:bazify, Foo, first_foo, user)).to eq true
      expect(AuthorizationAttrs.authorized?(:bazify, Foo, second_foo, user)).to eq false

      expect(AuthorizationAttrs.authorized?(:bazify, Foo, [first_foo, second_foo], user))
        .to eq false
    end

    it 'should return true if all of the records are authorized' do
      first_foo = Foo.create(bar_id: 1, taco_id: 2)
      second_foo = Foo.create(bar_id: 999, taco_id: 50)
      user = double(:user, bar_id: 1, taco_id: 50)

      AuthorizationAttrs.reset_attrs_for(first_foo)
      AuthorizationAttrs.reset_attrs_for(second_foo)

      expect(AuthorizationAttrs.authorized?(:bazify, Foo, first_foo, user)).to eq true
      expect(AuthorizationAttrs.authorized?(:bazify, Foo, second_foo, user)).to eq true

      expect(AuthorizationAttrs.authorized?(:bazify, Foo, [first_foo, second_foo], user))
        .to eq true
    end
  end
end
