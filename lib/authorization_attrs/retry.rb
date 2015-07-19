module Retry
  extend self

  def self.included(base)
    base.extend self
  end

  def with_retry(times: 3, sleep: 0, exception: StandardError)
    yield
  rescue exception
    raise unless times > 0
    times -= 1

    sleep sleep
    retry
  end
end
