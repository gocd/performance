require 'rest-client'
require 'nokogiri'

module GoCD
  class Client
    def initialize(base_url = 'http://localhost:8153/go',
                   rest_client: RestClient,
                   nokogiri: Nokogiri)
      @rest_client = rest_client
      @base_url = base_url
      @nokogiri = nokogiri
    end

    def create_pipeline(data)
      @rest_client.post("#{@base_url}/api/admin/pipelines",
                        data,
                        accept: 'application/vnd.go.cd.v1+json',
                        content_type: 'application/json')
    end

    def unpause_pipeline(name)
      @rest_client.post("#{@base_url}/api/pipelines/#{name}/unpause",
                        '',
                        confirm: true)
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
                        md5: md5)
    end

    def support_page
      @rest_client.get "#{@base_url}/api/support"
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
