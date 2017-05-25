require 'rest-client'
require 'nokogiri'
require 'open-uri'
require 'timeout'
require 'json'

module GoCD
  class Client

    def initialize(base_url = 'http://localhost:8153/go',
                   rest_client: RestClient,
                   nokogiri: Nokogiri)
      @rest_client = rest_client
      @base_url = base_url
      @nokogiri = nokogiri
      @auth_header = "Basic #{Base64.encode64(['admin', 'badger'].join(':'))}"
    end

    def create_pipeline(data)
      @rest_client.post("#{@base_url}/api/admin/pipelines",
                        data,
                        accept: 'application/vnd.go.cd.v3+json',
                        content_type: 'application/json', Authorization: @auth_header)
    end

    def delete_pipeline(pipeline)
      @rest_client.delete "#{@base_url}/api/admin/pipelines/#{pipeline}",
        :accept =>  'application/vnd.go.cd.v3+json', Authorization: @auth_header
    end

    def unpause_pipeline(name)
      @rest_client.post("#{@base_url}/api/pipelines/#{name}/unpause",
                        '',
                        confirm: true, Authorization: @auth_header)
    end

    def get_pipeline_count(name)
      history = JSON.parse(open("#{@base_url}/api/pipelines/#{name}/history/0",'Confirm' => 'true', http_basic_authentication: ["admin", "badger"]).read)
      begin
        history["pipelines"][0]["counter"]
      rescue => e
        "retry"
      end
    end

    def get_agent_id(idx)
      agents = JSON.parse(open("#{@base_url}/api/agents",'Accept' => 'application/vnd.go.cd.v4+json', http_basic_authentication: ["admin", "badger"]).read)
      agents['_embedded']['agents'][idx-1]['uuid']
    end

    def get_agents_count()
      agents = JSON.parse(open("#{@base_url}/api/agents",'Accept' => 'application/vnd.go.cd.v4+json', http_basic_authentication: ["admin", "badger"]).read)
      agents['_embedded']['agents'].length
    end

    def auto_register_key(key)
      server_attribute('agentAutoRegisterKey', key)
    end

    def job_timeout(timeout)
      server_attribute('jobTimeout', timeout)
    end

    def config_xml
      response = @rest_client.get "#{@base_url}/admin/configuration/file.xml"
      md5 = response.headers[:x_cruise_config_md5]

      unless md5
        raise 'Failed to get config, check authentication'
      end

      return response.to_str, md5
    end

    def save_config_xml(xml, md5)
      @rest_client.post("#{@base_url}/admin/configuration/file.xml",
                        xmlFile: xml,
                        md5: md5, Authorization: @auth_header)
    end

    def support_page
      @rest_client.get "#{@base_url}/api/support"
    end

    def set_auth_config
      config, md5 = config_xml

      xml = @nokogiri::XML config

      authConfigs = Nokogiri::XML::Node.new("authConfigs",xml)
      authConfig = Nokogiri::XML::Node.new("authConfig",authConfigs)
      authConfig['id'] = 'pwd_file'
      authConfig['pluginId'] = 'cd.go.authentication.passwordfile'
      property = Nokogiri::XML::Node.new("property",authConfig)
      key = Nokogiri::XML::Node.new("key",property)
      key.content = 'PasswordFilePath'
      value = Nokogiri::XML::Node.new("value",property)
      value.content = File.expand_path("resources/password.properties")
      property.add_child key
      property.add_child value

      authConfig.add_child property
      authConfigs.add_child authConfig

      xml.search("//server").first.add_child authConfigs
      @rest_client.post("#{@base_url}/admin/configuration/file.xml",
                        xmlFile: xml.to_xml,
                        md5: md5)

    end

    private

    def server_attribute(attribute, value)
      config, md5 = config_xml

      xml = @nokogiri::XML config

      xml.xpath('//server').each do |ele|
        ele.set_attribute(attribute, value)
      end

      save_config_xml xml.to_xml, md5
    end


  end
end
