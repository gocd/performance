require './lib/gocd'
require 'rest-client'

describe GoCD::Client do
  before(:each) do
    @rest_client = double('rest_client')
    @client = GoCD::Client.new(rest_client:@rest_client)
    @pipeline = GoCD::Pipeline.new(name: 'pipeline')
  end

  describe :create_pipeline do
    it 'posts to the right end point' do
      expect(@rest_client).to receive(:post).with("http://localhost:8153/go/api/admin/pipelines",
                                                  @pipeline.to_json,
                                                  :accept => 'application/vnd.go.cd.v1+json',
                                                  :content_type => 'application/json')
      @client.create_pipeline(@pipeline.to_json)
    end
    
    it 'sets the base_url' do
      client = GoCD::Client.new('base_url', rest_client:@rest_client)
      expect(@rest_client).to receive(:post).with("base_url/api/admin/pipelines",
                                                  @pipeline.to_json,
                                                  :accept => 'application/vnd.go.cd.v1+json',
                                                  :content_type => 'application/json')
      client.create_pipeline(@pipeline.to_json)
    end
  end

  describe :unpause_pipeline do
    it 'posts to the unpause end point' do
      expect(@rest_client).to receive(:post).with("http://localhost:8153/go/api/pipelines/pipeline/unpause",
                                                  "",
                                                  :'Confirm' => true)
      @client.unpause_pipeline(@pipeline.name) 
    end
  end
end
