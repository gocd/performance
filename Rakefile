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
require_relative 'scripts/init'
require 'rest-client'
require_relative 'lib/gocd'
require 'rake/rspec'

include GoCD

namespace :pipeline do
  desc "Create Pipelines"
  task :create do
    pipelines = [*1..NO_OF_PIPELINES].map{ |i| "perf#{i}"}

    pipelines.each {|pipeline|
      performance_pipeline = Pipeline.new(group: 'performance', name: "#{pipeline}")
      performance_pipeline << Material.new(type: 'git', attributes: { url: "git://#{GIT_REPOSITORY_SERVER}/git-repo-#{pipeline}"} )

      stage = Stage.new(name: 'default')
      performance_pipeline << stage

      job = Job.new(name: 'defaultJob')
      job << Task.new(type: 'exec', attributes: { command: 'ls' })
      stage << job

      begin
        RestClient.post "#{get_url}/api/admin/pipelines", 
          performance_pipeline.to_json,
          :accept =>  'application/vnd.go.cd.v1+json', 
          :content_type =>  'application/json'

        RestClient.post "#{get_url}/api/pipelines/#{performance_pipeline.name}/unpause",
          "", :'Confirm'=> true

      rescue => e
        raise "Something went wrong while creating pipeline #{pipeline}. \n Server says:\n #{e.response}"
      end
    }
    p "Created pipeline(s) #{pipelines.join(', ')} at #{get_url}/pipelines"
  end
end

task :start_stop_perf do
  begin
    prepare_jmeter_with_plugins
    set_agent_auto_register_key
    create_agents
    Rake::Task['pipeline:create']
    cleanup
    @scm_pid = scm_commit_loop
    @config_pid = config_update_loop
    warm_up
    ruby "scripts/run_test.rb"
  ensure
    p "Starting clean up Process for #{@scm_pid} and #{@config_pid}"
    destroy @scm_pid if defined? @scm_pid
    destroy @config_pid if defined? @config_pid
    stop_agents
    git_cleanup
  end
end

task :create_agents do
  set_agent_auto_register_key
  create_agents
end

task :start_server do
  start_server
end

task :shutdown_server do
  shutdown_server
end
