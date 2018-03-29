require './lib/configuration'
require './lib/material'
require 'rest-client'
require './lib/gocd'

include GoCD
include Configuration

namespace :pipeline do
  @setup = SetUp.new
  @distributor = Material::Distributor.new
  gocd_server = Server.new
  MULTISTAGE_PIPELINES_POOL = (0..((ENV['NO_OF_PIPELINES'].to_f/100)*ENV['PERCENT_MULTISTAGE_PIPELINES'].to_i).to_i)

  desc "Create Pipelines"
  task :create => :clean do
    gocd_client = Client.new(gocd_server.url)


    @setup.pipelines.each {|pipeline|
      performance_pipeline = Pipeline.new(group: 'performance', name: "#{pipeline}") do |p|
        @distributor.material_for(pipeline).each{ |material|
          p << material
        }

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
    }
    p "Created pipeline(s) #{@setup.pipelines.join(', ')}"
  end

  desc "Create Pipelines with Elastic agents set up"
  task :create_pipelines_to_run_on_elastic_agents, [:profile_id] do |t, args|
    gocd_client = Client.new(gocd_server.url)

    @setup.pipelines_run_on_elastic_agents.each {|pipeline|
      performance_pipeline = Pipeline.new(group: 'elastic-agents', name: "#{pipeline}") do |p|
        @distributor.material_for(pipeline).each{|material|
          p << material
        }
        p << Stage.new(name: 'default') do |s|
          s << Job.new(name: 'defaultJob1', elastic_profile_id: args[:profile_id]) do |j|
            j << ExecTask.new(command: 'ls')
          end
          s << Job.new(name: 'defaultJob2', elastic_profile_id: args[:profile_id]) do |j|
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
    }
    p "Created pipeline(s) #{@setup.pipelines_run_on_elastic_agents.join(', ')}"
  end

  desc "Clear pipelines"
  task :clean do
    gocd_client = Client.new(gocd_server.url)
    @setup.pipelines.reverse_each { |pipeline|
      begin
        gocd_client.delete_pipeline(pipeline)
      rescue RestClient::ResourceNotFound
      end
    }
  end

  private

  def multi_stage_pipeline?(pipeline_name)
    MULTISTAGE_PIPELINES_POOL.include? pipeline_name.gsub(/[^0-9]/, '').to_i
  end


end
