class Scenario

  attr_accessor :name, :url, :count, :rampup, :duration, :response_code

  def initialize(name, url)
    @name = name
    @url = url
    @count = 1
    @rampup = 1
    @duration = 30
    @response_code = 200
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
