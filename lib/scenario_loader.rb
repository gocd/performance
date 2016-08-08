require './lib/scenario'

class ScenarioLoader
  attr_reader :path, :scenarios_cache

  def initialize(path)
    @path = path
    @scenarios_cache = {}
  end

  private 

  def parse(scenario_file)
    @scenarios_cache[scenario_file] = scenarios("#{@path}/#{scenario_file}.scenario")
  end
end

