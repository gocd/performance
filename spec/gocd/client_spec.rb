require './lib/gocd'
require 'rest-client'

describe GoCD::Client do
  before(:each) do
    @rest_client = double('rest_client')
    @client = GoCD::Client.new(rest_client: @rest_client)
    @pipeline = GoCD::Pipeline.new(name: 'pipeline')
    @auth_header = "Basic #{Base64.encode64(['admin', 'badger'].join(':'))}"
  end

  it 'gets the support page' do
    expect(@rest_client).to receive(:get)
      .with("http://localhost:8153/go/api/support", {:Authorization=>@auth_header})
    @client.support_page
  end

  describe :create_pipeline do
    it 'posts to the right end point' do
      expect(@rest_client).to receive(:post)
        .with("http://localhost:8153/go/api/admin/pipelines",
      @pipeline.to_json,
      :accept => 'application/vnd.go.cd.v3+json',
      :content_type => 'application/json', Authorization: @auth_header)

      @client.create_pipeline(@pipeline.to_json)
    end

    it 'sets the base_url' do
      client = GoCD::Client.new('base_url', rest_client:@rest_client)
      expect(@rest_client).to receive(:post)
        .with("base_url/api/admin/pipelines",
      @pipeline.to_json,
      :accept => 'application/vnd.go.cd.v3+json',
      :content_type => 'application/json', Authorization: @auth_header)

      client.create_pipeline(@pipeline.to_json)
    end
  end

  describe :unpause_pipeline do
    it 'posts to the unpause end point' do
      expect(@rest_client).to receive(:post)
        .with("http://localhost:8153/go/api/pipelines/pipeline/unpause",
      "",
      confirm: true, Authorization: @auth_header)
      @client.unpause_pipeline(@pipeline.name)
    end
  end

  describe :config_xml do

    before :each do
      @response = double('response', to_str: '<xml/>')
      allow(@rest_client).to receive(:get) { @response }
    end

    it 'gets from the right end point' do
      allow(@response).to receive(:headers).and_return({'x_cruise_config_md5': 'md5'})
      expect(@rest_client).to receive(:get)
        .with("http://localhost:8153/go/admin/configuration/file.xml")
      @client.config_xml
    end

    it 'gets the xml and md5' do
      allow(@response).to receive(:headers).and_return({'x_cruise_config_md5': 'md5'})
      expect(@client.config_xml).to eq(['<xml/>', 'md5'])
    end

    it 'raises exception if md5 is not there in the header' do
      allow(@response).to receive(:headers).and_return({})
      expect{ @client.config_xml }.to raise_error ('Failed to get config, check authentication')
    end
  end

  describe :save_config_xml do
    it 'posts to the right end point' do
      expect(@rest_client).to receive(:post)
        .with("http://localhost:8153/go/admin/configuration/file.xml",
      xmlFile: '<xml/>',
      md5: 'md5')

      @client.save_config_xml('<xml/>', 'md5')
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

      @client.auto_register_key 'key'
    end
  end

  describe :set_job_timeout do
    before :each do
      xml = %{ <server jobTimeout="60" }
      response = double('response', to_str: xml)
      allow(response).to receive(:headers).and_return({'x_cruise_config_md5': 'md5'})
      allow(@rest_client).to receive(:get) { response }
    end

    it 'posts to the right end point' do
      expectedXml = %{<?xml version="1.0"?>\n<server jobTimeout="61"/>\n}

      expect(@rest_client).to receive(:post)
        .with("http://localhost:8153/go/admin/configuration/file.xml",
      xmlFile: expectedXml,
      md5: 'md5')

      @client.job_timeout 61
    end
  end

end
