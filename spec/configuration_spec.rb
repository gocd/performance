require './lib/configuration.rb' 
describe "Configuration" do
  describe Configuration::SetUp do
    before(:each) do
      @setup= Configuration::SetUp.new
    end
    it "creates an array of performance pipeline names" do
      ENV['NO_OF_PIPELINES'] = '3'
      expect(@setup.pipelines).to eq(['perf1', 'perf2', 'perf3'])
    end
    it "defaults to 10 pipelines when the environment variable is not set" do
      ENV['NO_OF_PIPELINES'] = nil
      expect(@setup.pipelines).to eq(['perf1', 'perf2', 'perf3', 'perf4', 'perf5', 'perf6', 'perf7', 'perf8', 'perf9', 'perf10'])
    end
    it "create an array on the number of agents" do
      ENV['NO_OF_AGENTS'] = '2'
      expect(@setup.agents).to eq([1,2])
    end
    it "defaults to 10 agents" do
      ENV['NO_OF_AGENTS'] = nil
      expect(@setup.agents).to eq([1,2,3,4,5,6,7,8,9,10])
    end
    it "sets the default git repository host" do
      expect(@setup.git_repository_host).to eq('http://localhost')
    end
    it 'return the go full and short version' do
      ENV['GO_VERSION'] = "16.7.0-3883"
      expect(@setup.go_version).to eq(['16.7.0', '3883'])
    end
    it 'raises error of version number is missing' do
      ENV['GO_VERSION'] = nil
      expect{ @setup.go_version }.to raise_error { "Missing GO_VERSION environment variable" }
    end
    it 'raises error if the GO_VERSION is not in the right format' do
      ENV['GO_VERSION'] = '16.0'
      expect { @setup.go_version }.to raise_error (%{"GO_VERSION format not right, 
      we need the version and build e.g. 16.0.0-1234"})
    end
  end

  describe Configuration::Server do
    before(:each) do
      @server = Configuration::Server.new
    end
    it "sets the server base url from SERVER env variable with default port" do
      ENV['GOCD_HOST'] = 'goserver'
      ENV['PORT'] = nil
      expect(@server.base_url).to eq('http://goserver:8153')
    end
    it "sets the server base url from SERVER and PORT environment variables" do
      ENV['GOCD_HOST'] = 'goserver' 
      ENV['PORT'] = '8253'
      expect(@server.base_url).to eq('http://goserver:8253')
    end
    it "sets the server base url using default SERVER and specified PORT" do
      ENV['GOCD_HOST'] = nil
      ENV['PORT'] = '8253'
      expect(@server.base_url).to eq('http://localhost:8253')
    end
    it "sets authentication in the server base url " do
      ENV['AUTH'] = 'admin:badger'
      ENV['PORT'] = '8253'
      ENV['GOCD_HOST'] = 'authenticated_url'
      expect(@server.base_url).to eq('http://admin:badger@authenticated_url:8253')
    end
    it "sets the url" do
     ENV['AUTH'] = nil
     ENV['PORT'] = '8153' 
     ENV['GOCD_HOST'] = "host"
     expect(@server.url).to eq('http://host:8153/go')
    end
  end
end
