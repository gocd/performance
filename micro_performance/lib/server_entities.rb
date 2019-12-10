require './lib/gocd/pipeline'
require './micro_performance/lib/server_entities'
require './micro_performance/lib/pipeline_manager'
require './micro_performance/lib/environment_manager'
require './micro_performance/lib/go_constants'
require 'rake'
require 'rest-client'
require 'json'
require 'pry'

module Server
    class Entities

        attr_reader :config_file
        attr_reader :pipelines
        attr_reader :environments

        def initialize(config_file_path)
            @config_file = JSON.parse(File.read(config_file_path))
            @pipelines = Server::PipelinesManager.new(@config_file['pipelines'])
            @environments = Server::EnvironmentsManager.new(@config_file['environments'])
        end

        def create
            @pipelines.create
            @environments.create
        end

    end

end
