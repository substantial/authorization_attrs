require 'spec_helper'

module AuthorizationAttrs
  describe DefaultFinder do
    before do
      stub_const "Bar", double(:bar, to_s: "Bar")
    end

    describe ".record_attrs_class" do
      it "should return the appropriate class to find .model_attrs" do
        model_attrs_class = double(:model_attrs_class)
        stub_const "Authorizations::BarAuthorizations", model_attrs_class

        expect(DefaultFinder.record_attrs_class(Bar)).to eq model_attrs_class
      end
    end

    describe ".user_attrs_class" do
      it "should return the appropriate class to find #user_attrs" do
        user_attrs_class = double(:user_attrs_class)
        stub_const "Authorizations::BarAuthorizations::UserAuthorizationAttrs",
          user_attrs_class

        expect(DefaultFinder.user_attrs_class(Bar)).to eq user_attrs_class
      end
    end
  end
end
