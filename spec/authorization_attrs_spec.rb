require 'spec_helper'

describe AuthorizationAttrs do
  let(:foo) { mock_model("Foo", bar_id: 1, taco_id: 2) }
  let(:user) { double(:user, bar_id: 1, taco_id: 90) }
  let(:authorizations_class) { double(:authorizations_class) }
  let(:authorizations_class_instance) { double(:authorizations_class_instance) }

  before do
    allow(AuthorizationAttrs::ActiveRecordStorageStrategy).to receive(:authorizations_match?)
    allow(AuthorizationAttrs::ActiveRecordStorageStrategy).to receive(:find_by_permission)
    allow(IdsFilter).to receive(:filter).with(foo) { "array of record ids" }

    allow(authorizations_class).to receive(:new).with(user) { authorizations_class_instance }
    allow(AuthorizationAttrs::DefaultFinder).to receive(:authorizations_class)
      .with(Foo) { authorizations_class }
  end

  describe ".authorize!" do
    it "should not raise an error if authorized" do
      allow(authorizations_class_instance).to receive(:bazify) { :all }

      expect { AuthorizationAttrs.authorize!(:bazify, Foo, foo, user) }
        .not_to raise_error AuthorizationAttrs::UnauthorizedAccessError
    end

    it "should raise an error if unauthorized" do
      allow(authorizations_class_instance).to receive(:bazify) { [] }

      expect { AuthorizationAttrs.authorize!(:bazify, Foo, foo, user) }
        .to raise_error AuthorizationAttrs::UnauthorizedAccessError
    end
  end

  describe ".authorized?" do
    it 'should return true if user attributes return :all' do
      allow(authorizations_class_instance).to receive(:bazify) { :all }

      authorized = AuthorizationAttrs.authorized?(:bazify, Foo, foo, user)

      expect(authorized).to eq true
    end

    it 'should return false if user attributes return an empty array' do
      allow(authorizations_class_instance).to receive(:bazify) { [] }

      authorized = AuthorizationAttrs.authorized?(:bazify, Foo, foo, user)

      expect(authorized).to eq false
    end

    it 'should return false if user attributes return nil' do
      allow(authorizations_class_instance).to receive(:bazify) { nil }

      authorized = AuthorizationAttrs.authorized?(:bazify, Foo, foo, user)

      expect(authorized).to eq false
    end

    it 'should delegate the comparison of attributes to the storage strategy' do
      allow(authorizations_class_instance).to receive(:bazify) { "array of user attrs" }

      AuthorizationAttrs.authorized?(:bazify, Foo, foo, user)

      expect(AuthorizationAttrs::ActiveRecordStorageStrategy).to have_received(:authorizations_match?).with(
        model: Foo,
        record_ids: "array of record ids",
        user_attrs: "array of user attrs"
      )
    end
  end

  describe ".find_by_permission" do
    it "should return an empty array if user attrs are nil" do
      allow(authorizations_class_instance).to receive(:bazify) { nil }

      expect(AuthorizationAttrs.find_by_permission(:bazify, Foo, user)).to eq []
    end

    it "should return an empty array if user attrs are empty" do
      allow(authorizations_class_instance).to receive(:bazify) { [] }

      expect(AuthorizationAttrs.find_by_permission(:bazify, Foo, user)).to eq []
    end

    it "should delegate to the storage_strategy" do
      allow(authorizations_class_instance).to receive(:bazify) { "array of user attrs" }

      AuthorizationAttrs.find_by_permission(:bazify, Foo, user)

      expect(AuthorizationAttrs::ActiveRecordStorageStrategy).to have_received(:find_by_permission)
        .with(model: Foo, user_attrs: "array of user attrs")
    end
  end

  describe '.user_attrs' do
    it "should delegate to a permission on the appropriate user-defined Authorizations class" do
      allow(authorizations_class_instance).to receive(:bazify) { "array of user attrs" }

      expect(AuthorizationAttrs.user_attrs(:bazify, Foo, user)).to eq "array of user attrs"
    end
  end

  describe ".record_attrs" do
    it "should delegate to the appropriate user-defined Authorizations class" do
      allow(authorizations_class).to receive(:record_attrs).with(foo) { "record attrs" }

      expect(AuthorizationAttrs.record_attrs(foo)).to eq "record attrs"
    end
  end

  describe ".reset_attrs_for" do
    it "should delegate to the storage strategy" do
      allow(authorizations_class).to receive(:record_attrs).with(foo) { "record attrs" }
      allow(AuthorizationAttrs::ActiveRecordStorageStrategy).to receive(:reset_attrs_for)

      AuthorizationAttrs.reset_attrs_for(foo)

      expect(AuthorizationAttrs::ActiveRecordStorageStrategy).to have_received(:reset_attrs_for)
        .with(foo, new_record_attrs: "record attrs")
    end
  end
end
