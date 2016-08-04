class Scenario
  attr_reader :name, :url, :count, :rampup, :duration, :response_code

  def initialize(name,
                 url: nil,
                 count: 1,
                 rampup: 1,
                 duration: 30,
                 response_code: 200)
    @name = name
    @url = url
    @count = count
    @rampup = rampup
    @duration = duration
    @response_code = response_code
  end
end

class Scenarios
  attr_reader :list

  def initialize
    @list = []
  end

  def add(scenario)
    @list << scenario
  end
end
