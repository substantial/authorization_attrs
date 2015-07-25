class IdsFilter
  def self.filter(record)
    new(record).filter
  end

  def initialize(record)
    @record = record
  end

  def filter
    if record.respond_to?(:id)
      record.id
    else
      record
    end
  end

  private

  attr_reader :record
end
