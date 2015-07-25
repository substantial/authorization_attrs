require "authorization_attrs/ids_filter"

describe IdsFilter do
  it "should return an arrayified id if an id is passed in" do
    expect(IdsFilter.filter(123)).to eq [123]
  end

  it "should return an arrayified id if the object responds to #id" do
    record = double(:record, id: 456)

    expect(IdsFilter.filter(record)).to eq [456]
  end

  it "should return an array of ids if passed ids" do
    expect(IdsFilter.filter([1, 2, 3])).to eq [1, 2, 3]
  end

  it "should return an array of ids if passed an array of records" do
    records = [double(:record, id: 2), double(:record, id: 3)]

    expect(IdsFilter.filter(records)).to eq [2, 3]
  end

  it "should return an array of ids if passed an array of mixed records and ids" do
    records = [double(:record, id: 2), 3]

    expect(IdsFilter.filter(records)).to eq [2, 3]
  end
end
