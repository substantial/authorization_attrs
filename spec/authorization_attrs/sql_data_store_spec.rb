module AuthorizationAttrs
  class FooAttrTestClass < ActiveRecord::Base; end

  describe SqlDataStore do
    before :all do
      ActiveRecord::Migration.suppress_messages do
        ActiveRecord::Migration.create_table :foo_attr_test_classes, temporary: true
      end
    end

    after :all do
      ActiveRecord::Migration.suppress_messages do
        ActiveRecord::Migration.drop_table :foo_attr_test_classes
      end
    end

    describe ".authorizations_match?", :db do
      let(:foo) { FooAttrTestClass.create }

      before do
        attrs = [{ bar_id: 1 }, { taco_id: 2 }]

        SqlDataStore.reset_attrs_for(foo, new_record_attrs: attrs)
      end

      it 'should return true if multiple attributes overlap' do
        user_attrs = [{ bar_id: 1 }, { taco_id: 2 }]

        authorized = SqlDataStore.authorizations_match?(
          record: foo,
          user_attrs: user_attrs
        )

        expect(authorized).to eq true
      end

      it 'should return true if one of the attributes overlap' do
        user_attrs = [{ bar_id: 1 }, { taco_id: 90 }]

        authorized = SqlDataStore.authorizations_match?(
          record: foo,
          user_attrs: user_attrs
        )

        expect(authorized).to eq true
      end

      it 'should return false if none of the attributes overlap' do
        user_attrs = [{ bar_id: "not a match" }, { taco_id: "not a match" }]

        authorized = SqlDataStore.authorizations_match?(
          record: foo,
          user_attrs: user_attrs
        )

        expect(authorized).to eq false
      end
    end

    describe ".serialize_attrs" do
      it "should generate attributes for users specific to permissions" do
        data = [{ bar_id: 1 }, { taco_id: 90 }]

        attrs = SqlDataStore.serialize_attrs(data)

        expect(attrs).to match_array ["bar_id=1", "taco_id=90"]
      end

      it 'should raise an error if a single hash is passed in' do
        data = { bar_id: 1 }

        expect { SqlDataStore.serialize_attrs(data) }
          .to raise_error ArgumentError
      end

      it 'should return an empty array if no attributes are returned' do
        data = []

        attrs = SqlDataStore.serialize_attrs(data)

        expect(attrs).to eq []
      end

      it 'should return an empty array if nil is returned for attributes' do
        data = nil

        attrs = SqlDataStore.serialize_attrs(data)

        expect(attrs).to eq []
      end

      it "should generate multiple attributes given more than one attribute hash" do
        data = [{ foo_id: 2 }, { bar: true }, { baz_id: nil }]

        attrs = SqlDataStore.serialize_attrs(data)

        expect(attrs).to eq(["foo_id=2", "bar=true", "baz_id="])
      end

      it "should generate compound attributes" do
        data = [{ bar: false, foo_id: 2 }]

        attrs = SqlDataStore.serialize_attrs(data)

        expect(attrs).to eq(["bar=false&foo_id=2"])
      end

      it "should generate the same compound attribute regardless of initial sorting" do
        data = [{ foo_id: 2, bar: false }]

        attrs = SqlDataStore.serialize_attrs(data)

        expect(attrs).to eq(["bar=false&foo_id=2"])
      end
    end

    describe ".reset_attrs_for", :db do
      let(:attrs) { [{ bar_id: 1 }, { taco_id: 2 }] }

      it "should not affect authorization attributes if they haven't changed" do
        foo = FooAttrTestClass.create

        allow(FooAttrTestClass).to receive(:create)

        AuthorizationAttr.create(authorizable: foo, name: "bar_id=1")
        AuthorizationAttr.create(authorizable: foo, name: "taco_id=2")

        SqlDataStore.reset_attrs_for(foo, new_record_attrs: attrs)

        new_attrs = AuthorizationAttr.where(authorizable: foo).map(&:name)

        expect(FooAttrTestClass).not_to have_received(:create)
        expect(new_attrs).to match_array ["bar_id=1", "taco_id=2"]
      end

      it "should add any new attributes" do
        foo = FooAttrTestClass.create

        AuthorizationAttr.create(authorizable: foo, name: "bar_id=1")

        SqlDataStore.reset_attrs_for(foo, new_record_attrs: attrs)

        new_attrs = AuthorizationAttr.where(authorizable: foo).map(&:name)

        expect(new_attrs).to match_array ["bar_id=1", "taco_id=2"]
      end

      it "should remove any old attributes" do
        foo = FooAttrTestClass.create

        allow(FooAttrTestClass).to receive(:create)

        AuthorizationAttr.create(authorizable: foo, name: "bar_id=1")
        AuthorizationAttr.create(authorizable: foo, name: "taco_id=2")
        AuthorizationAttr.create(authorizable: foo, name: "taco_id=4")

        SqlDataStore.reset_attrs_for(foo, new_record_attrs: attrs)

        new_attrs = AuthorizationAttr.where(authorizable: foo).map(&:name)

        expect(FooAttrTestClass).not_to have_received(:create)
        expect(new_attrs).to match_array ["bar_id=1", "taco_id=2"]
      end
    end
  end
end
