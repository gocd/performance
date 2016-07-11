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

def get_scenarios
	return JSON.parse(File.read('scripts/load_scenarios.json'))
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
