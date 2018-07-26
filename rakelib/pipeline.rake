require './lib/configuration'
require './lib/material'
require 'rest-client'
require './lib/gocd'
require './lib/gocd/config_repo_pipeline'

include GoCD
include Configuration

namespace :pipeline do
  @setup = SetUp.new
  @distributor = Material::Distributor.new

  MULTISTAGE_PIPELINES_POOL = (0..((ENV['NO_OF_PIPELINES'].to_f / 100) * ENV['PERCENT_MULTISTAGE_PIPELINES'].to_i).to_i)

  desc 'Create Pipelines in main config'
  task :create do
    
    clean(@setup.pipelines)
    @setup.pipelines.each do |pipeline|
      performance_pipeline = Pipeline.new(group: 'performance', name: pipeline.to_s) do |p|
        @distributor.material_for(pipeline).each do |material|
            p << material
        end

          if multi_stage_pipeline?(pipeline)
            p << Stage.new(name: 'first') do |s|
              s << Job.new(name: 'firstJob') do |j|
                j << ExecTask.new(command: 'ls')
              end
            end
          end

          p << Stage.new(name: 'default') do |s|
            s << Job.new(name: 'defaultJob') do |j|
              j << ExecTask.new(command: 'ls')
            end
          end
        end

        begin
          gocd_client.create_pipeline(performance_pipeline.to_json)
          gocd_client.unpause_pipeline(performance_pipeline.name)
        rescue => e
          raise "Something went wrong while creating pipeline #{pipeline}. \n Server says:\n #{e.response}"
        end
    end
    p "Created pipeline(s) #{@setup.pipelines.join(', ')}"
  end

  desc 'Create Pipelines in Config repo'
  task :create_in_config_repo do

    config_repo = Material::ConfigRepo.new
    #clean(@setup.pipelines_in_config_repo)
    @setup.pipelines_in_config_repo.each do |pipeline|
      performance_pipeline = ConfigRepoPipeline.new(group: 'ConfigRepo', name: pipeline.to_s) do |p|
        @distributor.material_for(pipeline).each do |material|
            p << material
        end

          if multi_stage_pipeline?(pipeline)
            p << Stage.new(name: 'first') do |s|
              s << Job.new(name: 'firstJob') do |j|
                j << ExecTask.new(command: 'ls')
              end
            end
          end

          p << Stage.new(name: 'default') do |s|
            s << Job.new(name: 'defaultJob') do |j|
              j << ExecTask.new(command: 'ls')
            end
          end
        end

        begin
          config_repo.create_repo(performance_pipeline.to_json, "#{pipeline.to_s}.gopipeline.json")
        rescue => e
          binding.pry
          raise "Something went wrong while creating config repo pipeline #{pipeline}. \n Config repo checkin says:\n #{e.message}"
        end
    end
    p "Created Config repo pipeline(s) #{@setup.pipelines_in_config_repo.join(', ')}"
  end

  desc 'Create Pipelines with ECS Elastic agents set up'
  task :create_pipelines_to_run_on_ecs_elastic_agents, [:profile_id] do |_t, args|
    if !@setup.include_ecs_elastic_agents?
      p "Not configuring pipelines to run on ECS elastic agents, as the plugin is not included in this run"
      next
    end

    clean(@setup.pipelines_run_on_ecs_elastic_agents)
    @setup.pipelines_run_on_ecs_elastic_agents.each do |pipeline|
      performance_pipeline = Pipeline.new(group: 'elastic-agents', name: pipeline.to_s) do |p|
        @distributor.material_for(pipeline).each do |material|
            p << material
        end
          p << Stage.new(name: 'default') do |s|
            s << Job.new(name: 'defaultJob', elastic_profile_id: args[:profile_id]) do |j|
              j << ExecTask.new(command: 'ls')
            end
          end
        end

        begin
          gocd_client.create_pipeline(performance_pipeline.to_json)
          gocd_client.unpause_pipeline(performance_pipeline.name)
        rescue => e
          raise "Something went wrong while creating pipeline #{pipeline}. \n Server says:\n #{e.response}"
        end
    end
      p "Created pipeline(s) #{@setup.pipelines_run_on_ecs_elastic_agents.join(', ')}"
  end

  desc 'Create Pipelines with K8S Elastic agents set up'
  task :create_pipelines_to_run_on_k8s_elastic_agents, [:profile_id] do |_t, args|
    if !@setup.include_k8s_elastic_agents?
      p "Not configuring pipelines to run on K8s elastic agents, as the plugin is not included in this run"
      next
    end

    clean(@setup.pipelines_run_on_k8s_elastic_agents)
    @setup.pipelines_run_on_k8s_elastic_agents.each do |pipeline|
      performance_pipeline = Pipeline.new(group: 'elastic-agents', name: pipeline.to_s) do |p|
        @distributor.material_for(pipeline).each do |material|
            p << material
        end
          p << Stage.new(name: 'default') do |s|
            s << Job.new(name: 'defaultJob', elastic_profile_id: args[:profile_id]) do |j|
              j << ExecTask.new(command: 'ls')
            end
          end
        end

        begin
          gocd_client.create_pipeline(performance_pipeline.to_json)
          gocd_client.unpause_pipeline(performance_pipeline.name)
        rescue => e
          raise "Something went wrong creating pipeline #{pipeline}. \n Server says:\n #{e.response}"
        end
      end
      p "Created pipeline(s) #{@setup.pipelines_run_on_k8s_elastic_agents.join(', ')}"
  end


  private

  def clean(pipelines)
    gocd_server = Server.new
    gocd_client = Client.new(gocd_server.url)
    pipelines.reverse_each do |pipeline|
        begin
          gocd_client.delete_pipeline(pipeline)
        rescue RestClient::ResourceNotFound
        end
    end
  end

  def multi_stage_pipeline?(pipeline_name)
    MULTISTAGE_PIPELINES_POOL.include? pipeline_name.gsub(/[^0-9]/, '').to_i
  end
end