require 'rubygems'
require 'ruby-jmeter'
require_relative 'load_scenarios'


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

end.run(path: ENV['JMETER_PATH'],
  file: 'jmeter.jmx',
  log: 'jmeter.log',
  properties: {"jmeter.save.saveservice.output_format" => "xml"})
#end.run(path: ENV['JMETER_PATH'], gui: true)
