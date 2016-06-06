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

require 'rubygems'
require 'ruby-jmeter'
require_relative 'load_scenarios'
require_relative 'init'

test do
  get_scenarios.each do |key, scenario|
    test_url = get_url scenario["url"]
    if scenario["name"] == "dashboard_api"
      threads count: scenario["count"], rampup: scenario["rampup"], duration: scenario["duration"] do
        get name: scenario["name"], url: test_url do
          scenario["header"].each do |header|
            header({name: header["name"], value: header["value"]})
          end
          assert equals: scenario["response_code"], test_field: 'Assertion.response_code'
          extract json: '$._embedded.pipeline_groups[0]._embedded.pipelines[0]._links.settings_path.href', name: 'general'
          extract json: '$._embedded.pipeline_groups[0]._embedded.pipelines[0]._links.self.href', name: 'history'
          extract json: '$._embedded.pipeline_groups[0]._embedded.pipelines[0]._embedded.instances[0]._links.self.href', name: 'stage'
          extract json: '$._embedded.pipeline_groups[0]._embedded.pipelines[0]._embedded.instances[0]._links.history_url.href', name: 'stage_history'
          extract json: '$._embedded.pipeline_groups[0]._embedded.pipelines[0]._embedded.instances[0]._links.vsm_url.href', name: 'vsm'
          extract json: '$._embedded.pipeline_groups[0]._embedded.pipelines[0]._embedded.instances[0]._links.compare_url.href', name: 'compare'
          extract json: '$._embedded.pipeline_groups[0]._embedded.pipelines[0]._embedded.instances[0]._links.build_cause_url.href', name: 'build_cause'
        end
        visit name: "general", url:'${general}' do
          assert equals: 200, test_field: 'Assertion.response_code'
        end
        visit name: "history", url:'${history}' do
          assert equals: 200, test_field: 'Assertion.response_code'
        end
        visit name: "stage", url:'${stage}' do
          assert equals: 200, test_field: 'Assertion.response_code'
        end
        visit name: "stage_history", url:'${stage_history}' do
          assert equals: 200, test_field: 'Assertion.response_code'
        end
        visit name: "vsm", url:'${vsm}' do
          assert equals: 200, test_field: 'Assertion.response_code'
        end
        visit name: "compare", url:'${compare}' do
          assert equals: 200, test_field: 'Assertion.response_code'
        end
        visit name: "build_cause", url:'${build_cause}' do
          assert equals: 200, test_field: 'Assertion.response_code'
        end
      end
    else
      threads count: scenario["count"], rampup: scenario["rampup"], duration: scenario["duration"] do
        visit name: scenario["name"], url: test_url
        assert equals: scenario["response_code"], test_field: 'Assertion.response_code'
      end
    end



  end

  log filename: 'custom.log', error_logging: true
  latencies_over_time 'Response Latencies Over Time'
  response_codes_per_second 'Response Codes per Second'
  response_times_distribution 'Response Times Distribution'
  response_times_over_time 'Response Times Over Time'
  response_times_percentiles 'Response Times Percentiles'

  perfmon_collector name: 'Perfmon Metrics Collector',
    nodes: [{
    server: 'localhost',
    port: 4444,
    metric: 'Memory',
    parameters: 'name=node#1:label=memory-node'
  },{
    server: 'localhost',
    port: 4444,
    metric: 'CPU',
    parameters: 'name=node#1:label=cpu-node'
  },{
    server: 'localhost',
    port: 4444,
    metric: 'JMX',
    parameters: 'url=localhost\:4711:gc-time'
  },{
    server: 'localhost',
    port: 4444,
    metric: 'JMX',
    parameters: 'url=localhost\:4711:memory-usage'
  }],
  filename: 'perf.jtl',
  xml: true

end.run(path: ENV['JMETER_PATH'],
        file: 'jmeter.jmx',
        log: 'jmeter.log',
        properties: {"jmeter.save.saveservice.output_format" => "xml"}, gui: false)
 # Add this to log response data -  "jmeter.save.saveservice.response_data" => "true" - expect logs to grow
