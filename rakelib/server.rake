require './lib/configuration'
require 'rest-client'

namespace :server do
  gocd_server = Configuration::Server.new
  task :prepare => :auto_register do
    
  end
  task :auto_register do
    response = RestClient.get "#{gocd_server.url}/admin/configuration/file.xml"
  
    md5 = response.headers['X-CRUISE-CONFIG-MD5']
    config = response.to_str
    

    puts "Previous MD5 was: #{md5}"
    xml = Nokogiri::XML(config)
    xml.xpath('//server').each do |ele|
      ele.set_attribute('agentAutoRegisterKey', 'perf-auto-register-key')
      ele.set_attribute('jobTimeout', '60')
    end
    params = "md5=#{md5}&xmlFile=#{CGI::escape(xml.to_xml)}"
    File.open(file = '/tmp/perf_config_file.xml', 'w') do |h|
      h.write(params)
    end
    reply = `curl -d @#{file} -i #{get_url}/admin/configuration/file.xml`
    puts "#{reply}\n==="
  end
end
