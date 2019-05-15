##########################################################################
# Copyright 2018 ThoughtWorks, Inc.
#
# Licensed under the Apache License, Version 2.0 (the License);
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an AS IS BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##########################################################################

require 'json'
require 'json_builder'
require 'rest-client'
require './lib/gocd'
require 'parallel'

module Plugins
  class Elastic_agent

    def initialize(file)
      @settings = JSON.parse(File.read(file))
    end

    def create_plugin_settings_with_actual_values(actuals, client)
      update_request_body_with(actuals, 'configuration')
      client.create_plugin_settings(@settings.to_json)
    end

    def create_cluster_profile_with_actual_values(actuals, client)
      update_request_body_with(actuals, 'properties')
      client.create_cluster_profile(@settings.to_json)
    end

    def update_request_body_with(actuals, entity_name)
      properties = @settings["#{entity_name}"].each{|key_value|
        actuals.each{|key, value|
          key_value['value'] = value if key_value['key'] == key
        }
      }
      @settings.each_with_object({}) { |(key, value), hash| hash[key] = properties if key == "#{entity_name}"}
    end
  end
end
