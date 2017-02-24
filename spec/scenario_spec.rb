require './lib/scenario'

describe :scenario do
  before(:example) do
    @scenario = Scenario.new
  end
  it 'has a name' do
    @scenario.name 'name'
    expect(@scenario.name).to eq('name')
  end
  it 'has a url' do
    @scenario.url 'url'
    expect(@scenario.url).to eq('url')
  end
  it 'has count' do
    @scenario.count 10
    expect(@scenario.count).to eq(10)
  end
  it 'sets default count' do
    expect(@scenario.count).to eq(1)
  end
  it 'has rampup' do
    @scenario.rampup 3
    expect(@scenario.rampup).to eq(3)
  end
  it 'sets default rampup' do
    expect(@scenario.rampup).to eq(1)
  end
  it 'has duration' do
    @scenario.duration 10
    expect(@scenario.duration).to eq(10)
  end
  it 'sets default duration' do
    expect(@scenario.duration).to eq(1200)
  end
  it 'has response code' do
    @scenario.response_code 500
    expect(@scenario.response_code).to eq(500)
  end
  it 'sets default response_code' do
    expect(@scenario.response_code).to eq(200)
  end
  it 'sets the thread information' do
    expect(@scenario.threads).to eq({ count:1, rampup:1 , duration:1200 })
  end
end

describe :scenarios do
  it 'adds scenario' do
    scenarios = Scenarios.new
    scenario = Scenario.new
    scenarios.add(scenario)
    expect(scenarios.list.first).to eq(scenario)
  end
end
