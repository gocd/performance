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
  return "#{PERF_SERVER_URL}/go#{path}"
end

def get_scenarios
	return JSON.parse(File.read('scripts/load_scenarios.json'))
end


def create_agents
  go_full_version = get_go_full_version
  version = go_full_version.split('-')[0]
  mkdir_p('go-agents')
  sh(%Q{wget -O go-agents/go-agent-#{go_full_version}.zip https://download.go.cd/experimental/binaries/#{go_full_version}/generic/go-agent-#{go_full_version}.zip})
  sh("unzip go-agents/go-agent-#{go_full_version}.zip -d go-agents/")

  (1..NO_OF_AGENTS).each{|i|
    cp_r "go-agents/go-agent-#{version}" , "go-agents/agent-#{i}"
    cp_r "scripts/autoregister.properties" ,  "go-agents/agent-#{i}/config/autoregister.properties"
    sh("chmod +x go-agents/agent-#{i}/agent.sh; GO_SERVER=#{PERF_SERVER_URL[/http:\/\/(.*?)\:/,1]} DAEMON=Y go-agents/agent-#{i}/agent.sh > /dev/null")
  }
end

def get_go_full_version
  json = JSON.parse(open(RELEASES_JSON_URL).read)
  version, release = json.sort {|a, b| a['go_full_version'] <=> b['go_full_version']}.last['go_full_version'].split('-')
  go_full_version = "#{version}-#{release}"
end

def start_server
  go_full_version = get_go_full_version
  version = go_full_version.split('-')[0]
  Dir.chdir("#{SERVER_DIR}") do
    mkdir_p('go-server')
    sh(%Q{wget -O go-server/go-server-#{go_full_version}.zip https://download.go.cd/experimental/binaries/#{go_full_version}/generic/go-server-#{go_full_version}.zip})
    sh("unzip go-server/go-server-#{go_full_version}.zip -d go-server/")
    sh("chmod +x go-server/go-server-#{version}/server.sh; DAEMON=Y go-server/go-server-#{version}/server.sh > /dev/null")
  end
  puts 'wait for server to come up'
  sh("wget #{get_url}/about --waitretry=90 --retry-connrefused --quiet -O /dev/null")
  start_jmeter_permon_agent
end

def start_jmeter_permon_agent
  if !Dir.exists?("#{JMETER_DIR}/perfmonAgent")
    Dir.chdir("#{JMETER_DIR}") do
      sh(%Q{wget -O perfmonAgent.zip http://jmeter-plugins.org/downloads/file/ServerAgent-2.2.1.zip})
      sh("unzip perfmonAgent.zip -d perfmonAgent")
      sh("perfmonAgent/startAgent.sh 2>&1 & > /dev/null")
      rm_rf('perfmonAgent.zip')
    end
  end
end

def shutdown_server
  version = get_go_full_version.split('-')[0]
  sh("sh scripts/stop_server.sh #{SERVER_DIR}/go-server/go-server-#{version}")
  rm_rf("#{SERVER_DIR}/go-server")
end

def stop_agents
  p "Stopping all agents"
  (1..NO_OF_AGENTS).each{|i|
    sh("chmod +x go-agents/agent-#{i}/stop-agent.sh; go-agents/agent-#{i}/stop-agent.sh > /dev/null")
  }
  rm_rf 'go-agents'
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
  GIT_REPOS.each do |repo_name|
    rm_rf "#{GIT_ROOT}/#{repo_name}"
  end
end

def checkin_git_repo
  Dir.chdir "#{GIT_ROOT}" do
    GIT_REPOS.each do |repo_name|
      git_repo = "#{GIT_ROOT}/#{repo_name}"
      (1..NO_OF_COMMITS).each do |i|
        sh("(cd #{git_repo}; echo #{rand(10**24-10)+10} > file;)")
        sh("cd #{git_repo}; git add .;git commit -m 'This is commit #{i}' --author 'foo <foo@bar.com>'")
      end
    end
  end
end


def cleanup
  rm_rf('jmeter.jmx')
  rm_rf('jmeter.log')
  rm_rf('custom.log')
  rm_rf('perf.jtl')
  rm_rf('jmeter.jtl')
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

def download
  ["http://mirror.fibergrid.in/apache//jmeter/binaries/apache-jmeter-3.0.zip",
    "http://jmeter-plugins.org/downloads/file/JMeterPlugins-Standard-1.4.0.zip",
    "http://jmeter-plugins.org/downloads/file/JMeterPlugins-Extras-1.4.0.zip",
    "http://jmeter-plugins.org/downloads/file/JMeterPlugins-ExtrasLibs-1.4.0.zip"].each do |url|

    sh("wget -P #{JMETER_DIR}/ #{url}")
    end
end

def extract_files
  puts "Extract files"
  Dir.chdir("#{JMETER_DIR}") do
    sh("unzip apache-jmeter-3.0.zip")
    sh("unzip JMeterPlugins-Extras-1.4.0.zip -d 1")
    sh("unzip JMeterPlugins-ExtrasLibs-1.4.0.zip -d 2")
    sh("unzip JMeterPlugins-Standard-1.4.0.zip -d 3")
  end
end

def setup_plugins_for_jmeter
  puts "Move all the plugins to jmeter"
  Dir.chdir("#{JMETER_DIR}") do
    [1,2,3].each do |dir_name|
      Dir["#{dir_name}/lib/*.jar"].each{|file| FileUtils.mv file, 'apache-jmeter-3.0/lib'}
      Dir["#{dir_name}/lib/ext/*.jar"].each{|file| FileUtils.mv file, 'apache-jmeter-3.0/lib/ext'}
    end
  end
end

def clean_up_directory
  puts "Clean up directory"
  Dir.chdir("#{JMETER_DIR}") do
    rm_rf("*.zip")
    [1,2,3].each do |dir_name|
      rm_rf("#{dir_name}")
    end
  end
end

def prepare_jmeter_with_plugins
  if File.directory?("#{JMETER_DIR}/apache-jmeter-3.0")
    p "Jmeter available at #{JMETER_DIR}/apache-jmeter-3.0 is being used"
  else
    download
    extract_files
    setup_plugins_for_jmeter
    clean_up_directory
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
