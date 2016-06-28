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
require './lib/configuration'
require 'rest-client'
require_relative 'lib/gocd'
require 'rake/rspec'

include GoCD

namespace :pipeline do
  configuration = Configuration.new

  desc "Create Pipelines"
  task :create => :clean do
    configuration.pipelines.each {|pipeline|
      performance_pipeline = Pipeline.new(group: 'performance', name: "#{pipeline}")
      performance_pipeline << GitMaterial.new(url: "git://#{configuration.git_repository_server}/git-repo-#{pipeline}")

      stage = Stage.new(name: 'default')
      job = Job.new(name: 'defaultJob')
      job << Task.new(type: 'exec', attributes: { command: 'ls' })
      stage << job

      performance_pipeline << stage

      begin
        RestClient.post "#{configuration.gocd_host}/api/admin/pipelines", 
          performance_pipeline.to_json,
          :accept =>  'application/vnd.go.cd.v1+json', 
          :content_type =>  'application/json'

        RestClient.post "#{configuration.gocd_host}/api/pipelines/#{performance_pipeline.name}/unpause",
          "", :'Confirm'=> true

      rescue => e
        raise "Something went wrong while creating pipeline #{pipeline}. \n Server says:\n #{e.response}"
      end
    }
    p "Created pipeline(s) #{configuration.pipelines.join(', ')} at #{configuration.gocd_host}/pipelines"
  end
  
  desc "Clear pipelines"
  task :clean do
    configuration.pipelines.each { |pipeline|
      begin
      RestClient.delete "#{configuration.gocd_host}/api/admin/pipelines/#{pipeline}", 
        :accept =>  'application/vnd.go.cd.v1+json'
      rescue RestClient::ResourceNotFound
      end
    }
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
