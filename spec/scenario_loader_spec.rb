require './lib/scenario_loader'

describe ScenarioLoader do
  it 'sets the path to scenarios' do
    expect(ScenarioLoader.new('path').path).to eq('path')
  end

  describe :read do
    before(:example) do
      loader = ScenarioLoader.new('./spec')
      @scenarios = loader.send :parse, 'test.scenario' 
    end
    it 'reads all scenarios_cache in the test file' do
      expect(@scenarios.list.count).to eq(1)
    end
    it 'sets the name of the scenario' do
      expect(@scenarios.list.first.name).to eq('test') 
    end
    it 'sets the url of the scenario' do
      expect(@scenarios.list.first.url).to eq('/url') 
    end
  end
end
