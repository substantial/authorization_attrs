require 'spec_helper'

module AuthorizationAttrs
  describe DefaultFinder do
    before do
      stub_const "Bar", double(:bar, to_s: "Bar")
    end

    describe ".record_attrs_class" do
      it "should return the appropriate class to find .record_attrs" do
        authorizations_class = double(:authorizations_class)
        stub_const "Authorizations::BarAuthorizations", authorizations_class

        expect(DefaultFinder.authorizations_class(Bar)).to eq authorizations_class
      end
    end
  end
end
