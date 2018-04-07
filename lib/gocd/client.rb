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
      @auth_header = "Basic #{Base64.encode64(['perf_tester', ENV['LDAP_USER_PWD']].join(':'))}"
    end

    def create_pipeline(data)
      @rest_client.post("#{@base_url}/api/admin/pipelines",
                        data,
                        accept: 'application/vnd.go.cd.v3+json',
                        content_type: 'application/json', Authorization: @auth_header)
    end

    def delete_pipeline(pipeline)
      @rest_client.delete "#{@base_url}/api/admin/pipelines/#{pipeline}",
                          accept: 'application/vnd.go.cd.v3+json' , Authorization: @auth_header
    end

    def unpause_pipeline(name)
      @rest_client.post("#{@base_url}/api/pipelines/#{name}/unpause",
                        '',
                        confirm: true , Authorization: @auth_header)
    end

    def create_plugin_settings(settings)
      @rest_client.post("#{@base_url}/api/admin/plugin_settings", settings,
                        content_type: :json, accept: 'application/vnd.go.cd.v1+json', Authorization: @auth_header)
    end

    def create_profile(profile)
      @rest_client.post("#{@base_url}/api/elastic/profiles", profile,
                        content_type: :json, accept: 'application/vnd.go.cd.v1+json', Authorization: @auth_header)
    end

    def get_pipeline_count(name)
      history = JSON.parse(open("#{@base_url}/api/pipelines/#{name}/history/0", 'Confirm' => 'true', http_basic_authentication: ['perf_tester', ENV['LDAP_USER_PWD']]).read)
      begin
        history['pipelines'][0]['counter']
      rescue => e
        'retry'
      end
    end

    def get_agent_id(idx)
      response = JSON.parse(open("#{@base_url}/api/agents", 'Accept' => 'application/vnd.go.cd.v4+json', http_basic_authentication: ['perf_tester', ENV['LDAP_USER_PWD']], read_timeout: 300).read)
      all_agents = response['_embedded']['agents']
      all_agents.map { |a| a['uuid'] unless a.key?('elastic_agent_id') }.compact[idx - 1] # pick only the physical agents, elastic agents are not long living
    end

    def get_agents_count
      agents = JSON.parse(open("#{@base_url}/api/agents", 'Accept' => 'application/vnd.go.cd.v4+json').read)
      agents['_embedded']['agents'].length
    end

    def auto_register_key(key)
      server_attribute('agentAutoRegisterKey', key)
    end

    def job_timeout(timeout)
      server_attribute('jobTimeout', timeout)
    rescue => e
      p "Config Update loop failed with exception #{e.message}"
    end

    def config_xml
      res = @rest_client.get("#{@base_url}/admin/configuration/file.xml") do |response, _request, _result|
        if response.code == 302
          @rest_client.get "#{@base_url}/admin/configuration/file.xml", Authorization: @auth_header
        else
          response
        end
      end
      md5 = res.headers[:x_cruise_config_md5]

      raise 'Failed to get config, check authentication' unless md5

      [res.to_str, md5]
    end

    def save_config_xml(xml, md5)
      @rest_client.post("#{@base_url}/admin/configuration/file.xml", { xmlFile: xml, md5: md5 }, Confirm: true) do |response, _request, _result|
        if response.code == 302
          @rest_client.post("#{@base_url}/admin/configuration/file.xml", { xmlFile: xml, md5: md5 }, Authorization: @auth_header, Confirm: true)
        end
      end
    end

    def enable_toggle(toggle)
      @rest_client.post("#{@base_url}/api/admin/feature_toggles/#{toggle}",
                        '{"toggle_value": "on"}',
                        content_type: :json, Authorization: @auth_header, Confirm: true)
    end

    def analyze_thread_dump(file, apikey)
      @rest_client.post "http://api.fastthread.io/fastthread-api?apiKey=#{apikey}", file, content_type: :text
    end

    def analyze_gc(file, apikey)
      @rest_client.post "http://api.gceasy.io/analyzeGC?apiKey=#{apikey}", file, content_type: :text
    end

    def support_page
      @rest_client.get "#{@base_url}/api/support", Authorization: @auth_header
    end

    def about_page
      @rest_client.get "#{@base_url}/about"
    end

    def set_file_based_auth_config(file)
      config, md5 = config_xml
      xml = @nokogiri::XML config

      authConfig = Nokogiri::XML::Node.new('authConfig', xml)
      authConfig['id'] = 'pwd_file'
      authConfig['pluginId'] = 'cd.go.authentication.passwordfile'
      property = Nokogiri::XML::Node.new('property', authConfig)
      key = Nokogiri::XML::Node.new('key', property)
      key.content = 'PasswordFilePath'
      value = Nokogiri::XML::Node.new('value', property)
      value.content = file
      property.add_child key
      property.add_child value

      authConfig.add_child property

      xml.search('//authConfigs').first.add_child authConfig

      save_config_xml xml.to_xml, md5
    end

    def set_ldap_auth_config(ldap_ip)
      response = @rest_client.get "#{@base_url}/admin/configuration/file.xml"
      md5 = response.headers[:x_cruise_config_md5]

      xml = @nokogiri::XML response.to_str

      ldap_config = "<security><authConfigs><authConfig id=\"ldap_authentication_plugin\" pluginId=\"cd.go.authentication.ldap\">
                  <property>
                      <key>Url</key>
                      <value>ldap://#{ldap_ip}</value>
                  </property>
                  <property>
                      <key>ManagerDN</key>
                      <value/>
                  </property>
                  <property>
                      <key>SearchBases</key>
                      <value>ou=People,dc=tests,dc=com
                      </value>
                  </property>
                  <property>
                      <key>UserLoginFilter</key>
                      <value>(uid={0})</value>
                  </property>
                  <property>
                      <key>Password</key>
                  </property>
              </authConfig></authConfigs></security>"

      xml.xpath('//server').first.add_child ldap_config
      @rest_client.post("#{@base_url}/admin/configuration/file.xml",
                        { xmlFile: xml.to_xml, md5: md5 }, Confirm: true)
    end

    def auth_enabled?
      @rest_client.get("#{@base_url}/about") do |response, _request, _result|
        response.code == 302
      end
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
