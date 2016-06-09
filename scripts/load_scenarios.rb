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
require_relative 'init'

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
    hash["pipeline"]["materials"][0]["attributes"]["url"]  = "git://#{GIT_REPOSITORY_SERVER}/git-repo-#{pipeline}"
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
    sh("chmod +x go-agents/agent-#{i}/agent.sh; GO_SERVER=#{GO_SERVER_URL[/http:\/\/(.*?)\:/,1]} DAEMON=Y go-agents/agent-#{i}/agent.sh > /dev/null")
  }
end

def stop_agents
  p "Stopping all agents"
  (1..NO_OF_AGENTS).each{|i|
    sh("chmod +x go-agents/agent-#{i}/stop-agent.sh; go-agents/agent-#{i}/stop-agent.sh > /dev/null")
  }
  sh('rm -rf go-agents')
end

def set_agent_auto_register_key
  response = `curl #{get_url}/admin/configuration/file.xml`
  response_with_headers = `curl -i #{get_url}/admin/configuration/file.xml`
  p response_with_headers
  md5 = response_with_headers[/X-CRUISE-CONFIG-MD5: (.*?)\r/,1]

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
  reply = `curl -d @#{file} -i #{get_url}/admin/configuration/file.xml`
  puts "#{reply}\n==="

end

def update_config
  response = `curl #{get_url}/admin/configuration/file.xml`
  response_with_headers = `curl -i #{get_url}/admin/configuration/file.xml`
  p response_with_headers
  md5 = response_with_headers[/X-CRUISE-CONFIG-MD5: (.*?)\r/,1]

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
  puts "#{reply}\n==="
end

def setup_git_repo
  create_git_repos
end

def create_git_repos
  GIT_REPOS.each do |repo_name|
    git_repo = "#{GIT_ROOT}/#{repo_name}"
    sh("git init #{git_repo}")
    sh("cd #{git_repo}; touch .git/git-daemon-export-ok")
    sh("touch #{git_repo}/file")
    sh("cd #{git_repo}; git add .")
    sh("cd #{git_repo}; git commit -m 'simple checkin' --author 'foo <foo@bar.com>'")
    puts "Creating repository #{git_repo}"
  end
  start_git_server
end

def start_git_server
    sh("git daemon --base-path=#{GIT_ROOT} --detach --syslog --export-all")
end

def git_cleanup
  sh("rm -rf #{GIT_ROOT}/git-repo-*")
end

def checkin_git_repo
  sh("cd #{GIT_ROOT}")
  GIT_REPOS.each do |repo_name|
    git_repo = "#{GIT_ROOT}/#{repo_name}"
    (1..NO_OF_COMMITS).each do |i|
      sh("(cd #{git_repo}; echo #{rand(10**24-10)+10} > file;)")
      sh("cd #{git_repo}; git add .;git commit -m 'This is commit #{i}' --author 'foo <foo@bar.com>'")
    end
  end
end


def cleanup
  FileUtils.rm_rf('jmeter.jmx')
  FileUtils.rm_rf('jmeter.log')
  FileUtils.rm_rf('custom.log')
  FileUtils.rm_rf('perf.jtl')
  FileUtils.rm_rf('jmeter.jtl')
end

def fork_and_loop command, sleep_time
  pid = fork do
    while true
      send(command)
      sleep(sleep_time)
    end
  end
  return pid
end

def scm_commit_loop
  setup_git_repo
  pid = fork_and_loop :checkin_git_repo , SCM_COMMIT_INTERVAL
end

def config_update_loop
  pid = fork_and_loop :update_config, CONFIG_UPDATE_INTERVAL
end

def extract_files
  puts "Extract files"
  sh("cd #{JMETER_PATH} && unzip apache-jmeter-3.0.zip")
  sh("cd #{JMETER_PATH} && unzip JMeterPlugins-Extras-1.4.0.zip -d 1")
  sh("cd #{JMETER_PATH} && unzip JMeterPlugins-ExtrasLibs-1.4.0.zip -d 2")
  sh("cd #{JMETER_PATH} && unzip JMeterPlugins-Standard-1.4.0.zip -d 3")
end

def setup_plugins_for_jmeter
  puts "Move all the plugins to jmeter"
  Dir.chdir("#{JMETER_PATH}") do
    [1,2,3].each do |dir_name|
      Dir["#{dir_name}/lib/*.jar"].each{|file| FileUtils.mv file, 'apache-jmeter-3.0/lib'}
      Dir["#{dir_name}/lib/ext/*.jar"].each{|file| FileUtils.mv file, 'apache-jmeter-3.0/lib/ext'}
    end
  end
end

def clean_up_directory
  puts "Clean up directory"
  sh("cd #{JMETER_PATH} && rm -rf *.zip")
  [1,2,3].each do |dir_name|
    sh("cd #{JMETER_PATH} && rm -rf #{dir_name}")
  end
end


def warm_up
  Timeout.timeout(180) do
    loop do
      agents = JSON.parse(open("#{get_url}/api/agents").read)
      break if agents.size == NO_OF_AGENTS
    end
  end
  sleep(180)
end


def destroy pid
  p "destroying child process #{pid}"
  Process.kill 9, pid
  Process.wait pid
end
