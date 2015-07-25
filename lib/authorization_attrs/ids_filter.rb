class IdsFilter
  def self.filter(records)
    new(records).filter
  end

  def initialize(records)
    @records = Array(records)
  end

  def filter
    records.map { |record| convert_to_id(record) }.uniq
  end

  private

  def convert_to_id(record)
    if record.respond_to?(:id)
      record.id
    else
      record
    end
  end

  attr_reader :records
end
