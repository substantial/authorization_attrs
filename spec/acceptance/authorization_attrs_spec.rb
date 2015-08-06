require 'spec_helper'

class Bar < ActiveRecord::Base
  has_many :authorization_attrs, as: :authorizable
end

module Authorizations
  class BarAuthorizations
    def self.record_attrs(bar)
      [
        { baz_id: bar.baz_id },
        { taco_id: bar.taco_id }
      ]
    end

    def initialize(user)
      @user = user
    end

    def bazify
      [
        { baz_id: user.baz_id },
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
      ActiveRecord::Migration.create_table :bars, temporary: true do |t|
        t.integer :baz_id
        t.integer :taco_id
      end
    end
  end

  after :all do
    ActiveRecord::Migration.suppress_messages do
      ActiveRecord::Migration.drop_table :bars
    end
  end

  let(:user) { double(:user, baz_id: 1, taco_id: 2) }

  def make_authorized_bar
    bar = Bar.create(baz_id: 1, taco_id: 999)
    AuthorizationAttrs.reset_attrs_for(bar)
    bar
  end

  def make_unauthorized_bar
    bar = Bar.create(baz_id: 999, taco_id: 999)
    AuthorizationAttrs.reset_attrs_for(bar)
    bar
  end

  describe "asserting authorizations" do
    it "should not raise an error if authorized" do
      expect { AuthorizationAttrs.authorize!(:bazify, Bar, make_authorized_bar, user) }
        .not_to raise_error
    end

    it "should raise an error if unauthorized" do
      expect { AuthorizationAttrs.authorize!(:bazify, Bar, make_unauthorized_bar, user) }
        .to raise_error AuthorizationAttrs::UnauthorizedAccessError
    end
  end

  describe "querying authorizations" do
    context "when a single record is queried" do
      it 'should return true if one of the attributes overlap' do
        expect(AuthorizationAttrs.authorized?(:bazify, Bar, make_authorized_bar, user)).to eq true
      end

      it 'can be called with an id' do
        expect(AuthorizationAttrs.authorized?(:bazify, Bar, make_authorized_bar.id, user)).to eq true
      end

      it 'should return false if none of the attributes overlap' do
        expect(AuthorizationAttrs.authorized?(:bazify, Bar, make_unauthorized_bar, user)).to eq false
      end
    end

    context "when multiple records are queried" do
      it 'should return false if all of the records are unauthorized' do
        expect(AuthorizationAttrs.authorized?(:bazify, Bar, [make_unauthorized_bar, make_unauthorized_bar], user))
          .to eq false
      end

      it 'should return false if any of the records are unauthorized' do
        expect(AuthorizationAttrs.authorized?(:bazify, Bar, [make_authorized_bar, make_unauthorized_bar], user))
          .to eq false
      end

      it 'should return true if all of the records are authorized' do
        expect(AuthorizationAttrs.authorized?(:bazify, Bar, [make_authorized_bar, make_authorized_bar], user))
          .to eq true
      end
    end
  end

  describe "finding records by permission" do
    it "should return an empty array if no records match" do
      first_bar, second_bar = make_unauthorized_bar, make_unauthorized_bar

      found_records = AuthorizationAttrs.find_by_permission(:bazify, Bar, user)

      expect(found_records).to eq []
    end

    it "should return only records that match" do
      first_bar, second_bar, third_bar = make_unauthorized_bar, make_authorized_bar, make_unauthorized_bar

      found_records = AuthorizationAttrs.find_by_permission(:bazify, Bar, user)

      expect(found_records).to eq [second_bar]
    end
  end
end
