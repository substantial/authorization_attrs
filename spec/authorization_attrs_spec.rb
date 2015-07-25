require 'spec_helper'

describe AuthorizationAttrs do
  let(:foo) { mock_model("Foo", bar_id: 1, taco_id: 2) }
  let(:user) { double(:user, bar_id: 1, taco_id: 90) }
  let(:user_attrs_class) { double(:user_attrs_class) }
  let(:user_attrs_class_instance) { double(:user_attrs_class_instance) }
  let(:record_attrs_class) { double(:record_attrs_class) }

  before do
    allow(AuthorizationAttrs::SqlDataStore).to receive(:authorizations_match?)
    allow(IdsFilter).to receive(:filter).with(foo) { "array of record ids" }

    allow(user_attrs_class).to receive(:new).with(user) { user_attrs_class_instance }
    allow(AuthorizationAttrs::DefaultFinder).to receive(:user_attrs_class) { user_attrs_class }
    allow(AuthorizationAttrs::DefaultFinder).to receive(:record_attrs_class).with(Foo) { record_attrs_class }
  end

  describe ".authorized?" do
    it 'should return true if user attributes return :all' do
      allow(user_attrs_class_instance).to receive(:bazify) { :all }

      authorized = AuthorizationAttrs.authorized?(:bazify, Foo, foo, user)

      expect(authorized).to eq true
    end

    it 'should return false if user attributes return an empty array' do
      allow(user_attrs_class_instance).to receive(:bazify) { [] }

      authorized = AuthorizationAttrs.authorized?(:bazify, Foo, foo, user)

      expect(authorized).to eq false
    end

    it 'should delegate the comparison of attributes to the storage strategy' do
      allow(user_attrs_class_instance).to receive(:bazify) { "array of user attrs" }

      AuthorizationAttrs.authorized?(:bazify, Foo, foo, user)

      expect(AuthorizationAttrs::SqlDataStore).to have_received(:authorizations_match?).with(
        model: Foo,
        record_ids: "array of record ids",
        user_attrs: "array of user attrs"
      )
    end
  end

  describe '.user_attrs' do
    it "should delegate to the appropriate permission on UserAuthorizationAttrs" do
      allow(user_attrs_class_instance).to receive(:bazify) { "array of user attrs" }

      expect(AuthorizationAttrs.user_attrs(:bazify, Foo, user)).to eq "array of user attrs"
    end
  end

  describe ".record_attrs" do
    it "should delegate to the appropriate user-defined Authorizations module" do
      allow(record_attrs_class).to receive(:record_attrs).with(foo) { "record attrs" }

      expect(AuthorizationAttrs.record_attrs(foo)).to eq "record attrs"
    end
  end

  describe ".reset_attrs_for" do
    it "should delegate to the storage strategy" do
      allow(record_attrs_class).to receive(:record_attrs).with(foo) { "record attrs" }
      allow(AuthorizationAttrs::SqlDataStore).to receive(:reset_attrs_for)

      AuthorizationAttrs.reset_attrs_for(foo)

      expect(AuthorizationAttrs::SqlDataStore).to have_received(:reset_attrs_for)
        .with(foo, new_record_attrs: "record attrs")
    end
  end
end
