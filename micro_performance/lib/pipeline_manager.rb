require './lib/gocd/pipeline'
require './micro_performance/lib/server_entities'
require './micro_performance/lib/go_constants'
require 'rake'
require 'rest-client'
require 'json'
require 'pry'

module Server

    class PipelinesManager

        attr_reader :pipelines

        def initialize(pipelines)
            @pipelines = pipelines
        end

        def create
            if @pipelines.nil?
                p 'No pipelines to create'
                return
            end

            raise "Pipelines count is mandatory property but not provided" if @pipelines['count'].nil?

            (1..@pipelines['count'].to_i).each do |pipeline|
                performance_pipeline = Pipeline.new(group: 'performance', name: "go-perf-#{pipeline}") do |p|
                    p << GitMaterial.new(name: 'material', url: "git://repos/git-repo-#{pipeline}", destination: 'git-repo')

                    p << Stage.new(name: 'first') do |s|
                        s << Job.new(name: 'firstJob') do |j|
                        j << ExecTask.new(command: 'ls')
                        end
                    end

                  p << Stage.new(name: 'second') do |s|
                    s << Job.new(name: 'secondJob') do |j|
                      j << ExecTask.new(command: 'ls')
                    end
                  end
                end

                begin
                  call_pipeline_api(performance_pipeline.to_json)
                rescue StandardError => e
                  raise "Something went wrong while creating pipeline #{pipeline}. \n Server says:\n #{e.response}"
                end
            end
        end

        def call_pipeline_api(data)
            RestClient.post("#{GoConstants::BASE_URL}/api/admin/pipelines",
                data,
                accept: 'application/vnd.go.cd+json',
                content_type: 'application/json', Authorization: GoConstants::AUTH_HEADER)
        end

    end


end
