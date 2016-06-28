require './lib/configuration.rb'

describe "Configuration" do
  before(:each) do
    @configuration = Configuration.new
  end
  it "creates an array of performance pipeline names" do
    ENV['NO_OF_PIPELINES'] = '3'
    expect(@configuration.pipelines).to eq(['perf1', 'perf2', 'perf3'])
  end
  it "defaults to 10 pipelines when the environment variable is not set" do
    ENV['NO_OF_PIPELINES'] = nil
    expect(@configuration.pipelines).to eq(['perf1', 'perf2', 'perf3', 'perf4', 'perf5', 'perf6', 'perf7', 'perf8', 'perf9', 'perf10'])
  end
  it "create an array on the number of agents" do
    ENV['NO_OF_AGENTS'] = '2'
    expect(@configuration.agents).to eq([1,2])
  end
  it "defaults to 10 agents" do
   ENV['NO_OF_AGENTS'] = nil
   expect(@configuration.agents).to eq([1,2,3,4,5,6,7,8,9,10])
  end
  it "sets the server url from SERVER env variable with default port" do
    ENV['SERVER'] = 'goserver'
    ENV['PORT'] = nil
    expect(@configuration.server_url).to eq('http://goserver:8153')
  end
  it "sets the server url from SERVER and PORT environment variables" do
   ENV['SERVER'] = 'goserver' 
   ENV['PORT'] = '8253'
   expect(@configuration.server_url).to eq('http://goserver:8253')
  end
  it "sets the server url using default SERVER and specified PORT" do
   ENV['SERVER'] = nil
   ENV['PORT'] = '8253'
   expect(@configuration.server_url).to eq('http://localhost:8253')
  end
end
