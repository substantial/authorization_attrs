require 'spec_helper'

describe AuthorizationAttrs do
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
      def self.model_attrs(foo)
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

  let(:foo) { mock_model(Foo, bar_id: 1, taco_id: 2) }
  let(:user) { double(:user, bar_id: 1, taco_id: 90) }

  describe "acceptance specs" do
    let(:foo) { Foo.create }

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

    it 'should return false if none of the attributes overlap' do
      allow(user).to receive(:bar_id) { "nope" }
      allow(user).to receive(:taco_id) { "nope" }
      AuthorizationAttrs.reset_attrs_for(foo)

      authorized = AuthorizationAttrs.authorized?(:bazify, Foo, foo.id, user)

      expect(authorized).to eq false
    end
  end

  describe ".authorized?" do
    before do
      allow(AuthorizationAttrs::SqlDataStore).to receive(:authorizations_match?)
      allow(IdsFilter).to receive(:filter).with(foo) { 'foo_id' }
    end

    it 'should return true if user attributes return :all' do
      allow_any_instance_of(Authorizations::FooAuthorizations::UserAuthorizationAttrs)
        .to receive(:bazify) { :all }

      authorized = AuthorizationAttrs.authorized?(:bazify, Foo, foo, user)

      expect(authorized).to eq true
    end

    it 'should return false if user attributes return an empty array' do
      allow_any_instance_of(Authorizations::FooAuthorizations::UserAuthorizationAttrs)
        .to receive(:bazify) { [] }

      authorized = AuthorizationAttrs.authorized?(:bazify, Foo, foo, user)

      expect(authorized).to eq false
    end

    it 'should delegate the comparison of attributes to the storage strategy' do
      AuthorizationAttrs.authorized?(:bazify, Foo, foo, user)

      expect(AuthorizationAttrs::SqlDataStore).to have_received(:authorizations_match?).with(
        model: Foo,
        record_id: 'foo_id',
        user_attrs: [{ bar_id: 1 }, { taco_id: 90 }]
      )
    end
  end

  describe '.user_attrs' do
    it "should generate the authorization attributes data for that user and permission" do
      attrs = AuthorizationAttrs.user_attrs(:bazify, Foo, user)

      expect(attrs).to match_array [{ bar_id: 1 }, { taco_id: 90 }]
    end
  end

  describe ".model_attrs" do
    it "should generate the authorization attributes data for that record" do
      attrs = AuthorizationAttrs.model_attrs(foo)

      expect(attrs).to match_array [{ bar_id: 1 }, { taco_id: 2 }]
    end
  end

  describe ".reset_attrs_for" do
    it "should delegate to the storage strategy" do
      allow(AuthorizationAttrs::SqlDataStore).to receive(:reset_attrs_for)

      AuthorizationAttrs.reset_attrs_for(foo)

      expect(AuthorizationAttrs::SqlDataStore).to have_received(:reset_attrs_for)
        .with(foo, new_record_attrs: [{ bar_id: 1 }, { taco_id: 2 }])
    end
  end
end
