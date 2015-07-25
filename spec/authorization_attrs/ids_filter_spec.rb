require "authorization_attrs/ids_filter"

describe IdsFilter do
  it "should return an id if an id is passed in" do
    expect(IdsFilter.filter(3)).to eq 3
  end

  it "should return an id if the object responds to #id" do
    record = double(:record, id: 2)

    expect(IdsFilter.filter(record)).to eq 2
  end
end
