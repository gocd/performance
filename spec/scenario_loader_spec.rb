require './lib/scenario_loader'

describe ScenarioLoader do
  it 'sets the path to scenarios' do
    expect(ScenarioLoader.new('path').path).to eq('path')
  end

  describe :read do
    before(:example) do
      @loader = ScenarioLoader.new('./spec')
      @loader.send :parse, 'test' 
    end
    it 'reads all scenarios_cache in the test file' do
      expect(@loader.scenarios_cache['test'].list.count).to eq(1)
    end
    it 'sets the name of the scenario' do
      expect(@loader.scenarios_cache['test'].list.first.name).to eq('test') 
    end
    it 'sets the url of the scenario' do
      expect(@loader.scenarios_cache['test'].list.first.url).to eq('/url') 
    end
  end
end
