require './lib/gocd'
require 'rest-client'
require 'pry'

describe GoCD::Client do
  before(:each) do
    @rest_client = double('rest_client')
    @client = GoCD::Client.new(rest_client: @rest_client)
    @pipeline = GoCD::Pipeline.new(name: 'pipeline')
  end

  describe :create_pipeline do
    it 'posts to the right end point' do
      expect(@rest_client).to receive(:post)
        .with("http://localhost:8153/go/api/admin/pipelines",
      @pipeline.to_json,
      :accept => 'application/vnd.go.cd.v1+json',
      :content_type => 'application/json')

      @client.create_pipeline(@pipeline.to_json)
    end
    
    it 'sets the base_url' do
      client = GoCD::Client.new('base_url', rest_client:@rest_client)
      expect(@rest_client).to receive(:post)
        .with("base_url/api/admin/pipelines",
      @pipeline.to_json,
      :accept => 'application/vnd.go.cd.v1+json',
      :content_type => 'application/json')

      client.create_pipeline(@pipeline.to_json)
    end
  end

  describe :unpause_pipeline do
    it 'posts to the unpause end point' do
      expect(@rest_client).to receive(:post)
        .with("http://localhost:8153/go/api/pipelines/pipeline/unpause",
      "",
      :'Confirm' => true)
      @client.unpause_pipeline(@pipeline.name) 
    end
  end

  describe :get_config_xml do

    before :each do
      @response = double('response', to_str: '<xml/>')
      allow(@rest_client).to receive(:get) { @response }
    end

    it 'gets from the right end point' do
      allow(@response).to receive(:headers).and_return({'x_cruise_config_md5': 'md5'})
      expect(@rest_client).to receive(:get)
        .with("http://localhost:8153/go/admin/configuration/file.xml")
      @client.get_config_xml
    end

    it 'gets the xml and md5' do
      allow(@response).to receive(:headers).and_return({'x_cruise_config_md5': 'md5'})
      expect(@client.get_config_xml).to eq(['<xml/>', 'md5'])
    end
    
    it 'raises exception if md5 is not there in the header' do
      allow(@response).to receive(:headers).and_return({})
      expect{ @client.get_config_xml }.to raise_error { 
         'MD5 of the content is missing in the header, Please make sure you are authenticated or using the right url' } 
    end
  end

  describe :set_config_xml do
    it 'posts to the right end point' do
      expect(@rest_client).to receive(:post)
        .with("http://localhost:8153/go/admin/configuration/file.xml", 
      xmlFile: '<xml/>', 
      md5: 'md5')
      
      @client.set_config_xml('<xml/>', 'md5')
    end

  end

  describe :set_auto_register do
    before :each do
      xml = %{ <server agentAutoRegisterKey="nothing" }
      response = double('response', to_str: xml)
      allow(response).to receive(:headers).and_return({'x_cruise_config_md5': 'md5'})
      allow(@rest_client).to receive(:get) { response }
    end

    it 'posts to the right end point' do
      expectedXml = %{<?xml version="1.0"?>\n<server agentAutoRegisterKey="key"/>\n}

      expect(@rest_client).to receive(:post)
        .with("http://localhost:8153/go/admin/configuration/file.xml", 
      xmlFile: expectedXml, 
      md5: 'md5')

      @client.set_auto_register_key 'key'
    end
  end

end
