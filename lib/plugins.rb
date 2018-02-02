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
      properties = @settings['configuration'].each{|key_value|
        actuals.each{|key, value|
          key_value['value'] = value if key_value['key'] == key
        }
      }
      @settings.each_with_object({}) { |(key, value), hash| hash[key] = properties if key == 'configuration'}
      client.create_plugin_settings(@settings.to_json)
    end
  end
end
