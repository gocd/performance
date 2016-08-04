require './lib/scenario'

describe :scenario do
  it 'has a name' do
    scenario = Scenario.new('name')
    expect(scenario.name).to eq('name')
  end
  it 'has a url' do
    scenario = Scenario.new('name', url: 'url')
    expect(scenario.url).to eq('url')
  end
  it 'has count' do
    scenario = Scenario.new('name', count:10)
    expect(scenario.count).to eq(10)
  end
  it 'sets default count' do
    scenario = Scenario.new('name')
    expect(scenario.count).to eq(1)
  end
  it 'has rampup' do
    scenario = Scenario.new('name', rampup:3)
    expect(scenario.rampup).to eq(3)
  end
  it 'sets default rampup' do
    scenario = Scenario.new('name')
    expect(scenario.rampup).to eq(1)
  end
  it 'has duration' do
    scenario = Scenario.new('name', duration:10)
    expect(scenario.duration).to eq(10)
  end
  it 'sets default duration' do
    scenario = Scenario.new('name')
    expect(scenario.duration).to eq(30)
  end
  it 'has response code' do
    scenario = Scenario.new('name', response_code:500)
    expect(scenario.response_code).to eq(500)
  end
  it 'sets default response_code' do
    scenario = Scenario.new('name')
    expect(scenario.response_code).to eq(200)
  end
end

describe :scenarios do
  it 'adds scenario' do
    scenarios = Scenarios.new
    scenario = Scenario.new('name')
    scenarios.add(scenario)
    expect(scenarios.list.first).to eq(scenario)
  end
end
