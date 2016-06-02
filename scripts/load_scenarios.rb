#!/usr/bin/ruby
##########################################################################
# Copyright 2016 ThoughtWorks, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##########################################################################

require 'json'
require 'nokogiri'
require 'cgi'

NO_OF_PIPELINES = ENV["NO_OF_PIPELINES"] || 10
NO_OF_AGENTS = ENV["NO_OF_AGENTS"]  || 5
GO_SERVER_URL = ENV["GO_SERVER_URL"] || "http://localhost:8153"
GO_SERVER_SSH_URL = ENV["GO_SERVER_SSH_URL"] || "https://localhost:8154"
RELEASES_JSON_URL = 'https://download.go.cd/experimental/releases.json'

def get_url path=''
  return "#{GO_SERVER_URL}/go#{path}"
end

def get_scenarios
	return JSON.parse(File.read('scripts/load_scenarios.json'))
end

def create_pipelines
  (1..NO_OF_PIPELINES).each {|pipeline|
    url = "#{get_url}/api/admin/pipelines"
    hash = JSON.parse(File.read('scripts/pipeline.json'))
    hash["pipeline"]["name"] = "perfpipeline_#{pipeline}"
    fJson = File.open("scripts/pipeline.json","w")
    fJson.write(hash.to_json)
    fJson.close
    puts 'create a pipeline'
    sh(%Q{curl -sL -w "%{http_code}" -X POST  -H "Accept: application/vnd.go.cd.v1+json" -H "Content-Type: application/json" --data "@scripts/pipeline.json" #{url} -o /dev/null})
    sh(%Q{curl -sL -w "%{http_code}" -X POST  -H "Accept:application/vnd.go.cd.v1+text" -H "CONFIRM:true" #{get_url}/api/pipelines/perfpipeline_#{pipeline}/unpause -o /dev/null})
  }

end

def create_agents

  json = JSON.parse(open(RELEASES_JSON_URL).read)
  version, release = json.sort {|a, b| a['go_full_version'] <=> b['go_full_version']}.last['go_full_version'].split('-')
  go_full_version = "#{version}-#{release}"

  sh('mkdir go-agents')
  sh(%Q{wget -O go-agents/go-agent-#{go_full_version}.zip https://download.go.cd/experimental/binaries/#{go_full_version}/generic/go-agent-#{go_full_version}.zip})
  sh("unzip go-agents/go-agent-#{go_full_version}.zip -d go-agents/")

  (1..NO_OF_AGENTS).each{|i|
    sh("cp -r go-agents/go-agent-#{version} go-agents/agent-#{i}")
    sh("cp scripts/autoregister.properties go-agents/agent-#{i}/config/autoregister.properties")
    sh("chmod +x go-agents/agent-#{i}/agent.sh; GO_SERVER=#{GO_SERVER_URL[/http:\/\/(.*?)\:/,1]} go-agents/agent-#{i}/agent.sh 2>&1 &")
  }
end

def set_agent_auto_register_key
  response = `curl #{get_url}/admin/configuration/file.xml`
  response_with_headers = `curl -i #{get_url}/admin/configuration/file.xml`
  md5 = response_with_headers.scan(/X-CRUISE-CONFIG-MD5: (.*)\r/)

  puts "Previous MD5 was: #{md5}"
  xml = Nokogiri::XML(response)
  xml.xpath('//server').each do |ele|
    ele.set_attribute('agentAutoRegisterKey', 'perf-auto-register-key')
    ele.set_attribute('jobTimeout', '60')
  end
  params = "md5=#{md5}&xmlFile=#{CGI::escape(xml.to_xml)}"
  File.open(file = '/tmp/perf_config_file.xml', 'w') do |h|
    h.write(params)
  end
  reply = `curl -i #{get_url}/admin/configuration/file.xml -d @#{file}`

end

def update_config
  response = `curl #{get_url}/admin/configuration/file.xml`
  response_with_headers = `curl -i #{get_url}/admin/configuration/file.xml`
  md5 = response_with_headers.scan(/X-CRUISE-CONFIG-MD5: (.*)\r/)

  puts "Previous MD5 was: #{md5}"
  if response.include? 'jobTimeout="61"'
    response.gsub!(/jobTimeout="61"/, 'jobTimeout="60"')
  else
    response.gsub!(/jobTimeout="60"/, 'jobTimeout="61"')
  end
  params = "md5=#{md5}&xmlFile=#{CGI::escape(response)}"
  File.open(file = '/tmp/perf_config_file.xml', 'w') do |h|
    h.write(params)
  end
  reply = `curl -i #{get_url}/admin/configuration/file.xml -d @#{file}`
end

def checkin_git_repo
  sh(%Q{cd /tmp/testrepo.git ; echo "next commit" >> file.txt ; git add . ; git commit -m "commit"})
end

def setup_git_repo
  FileUtils.remove_dir("/tmp/testrepo.git") if File.directory?("/tmp/testrepo.git")
  sh("git init /tmp/testrepo.git")
  sh(%Q{cd /tmp/testrepo.git ; echo "first commit" >> file.txt ; git add . ; git commit -m "commit"})
end


def warm_up

end


def destroy pid
  Process.kill 9, pid
  Process.wait pid
end
