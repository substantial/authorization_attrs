require 'spec_helper'

class Foo < ActiveRecord::Base
  def bar_id
    1
  end

  def taco_id
    2
  end
end

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
  let(:foo) { Foo.create }
  let(:user) { double(:user, bar_id: 1, taco_id: 90) }

  before :all do
    ActiveRecord::Migration.suppress_messages do
      ActiveRecord::Migration.create_table :foos, temporary: true
    end
  end

  after :all do
    ActiveRecord::Migration.suppress_messages do
      ActiveRecord::Migration.drop_table :foos
    end
  end

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
