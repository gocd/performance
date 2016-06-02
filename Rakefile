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

require "fileutils"
require 'json'
require 'open-uri'
require_relative 'scripts/load_scenarios'

$stoptest=false
CONFIG_UPDATE_INTERVAL = ENV['CONFIG_UPDATE_INTERVAL'] || 60
SCM_COMMIT_INTERVAL = ENV['SCM_UPDATE_INTERVAL'] || 60

task :start_perf do
  cleanup
  @scm_pid = scm_commit_loop
  @config_pid = config_update_loop
  warm_up
  ruby "scripts/run_test.rb"
  destroy @scm_pid
  destroy @config_pid
end

def cleanup
  File.delete('jmeter.jmx') if File.exists?('jmeter.jmx')
  File.delete('jmeter.log') if File.exists?('jmeter.log')
  File.delete('custom.log') if File.exists?('custom.log')
  File.delete('jmeter.jtl') if File.exists?('jmeter.jtl')
  File.delete('perf.jtl') if File.exists?('perf.jtl')
end

def scm_commit_loop
  pid = fork do
    setup_git_repo
    loop do
      checkin_git_repo
      sleep(SCM_COMMIT_INTERVAL)
    end
  end
  pid
end

def config_update_loop
  pid = fork do
    loop do
      update_config
      sleep(CONFIG_UPDATE_INTERVAL)
    end
  end
  pid
end

task :create_agents do
  set_agent_auto_register_key
  create_agents
end

task :create_pipelines do
  create_pipelines
end

task :do_perf_test => [:create_agents, :create_pipelines, :start_perf]
