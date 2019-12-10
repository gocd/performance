require './micro_performance/lib/server_entities'
require './micro_performance/lib/go_constants'
require 'rest-client'
require 'json'
require 'pry'

module Server

    class EnvironmentsManager

        attr_reader :envionments

        def initialize(environments)
            @envionments = environments
        end

        def create
            if @envionments.nil?
                p "No enviornments to create"
                return
            end
        end
    end
end
