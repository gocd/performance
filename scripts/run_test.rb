require 'rubygems'
require 'ruby-jmeter'
require_relative 'load_scenarios'


test do
	get_scenarios.each do |key, scenario|
		threads count: scenario["count"], rampup: scenario["rampup"], duration: scenario["duration"] do
			visit name: scenario["name"], url: scenario["url"]
			assert equals: '200', test_field: 'Assertion.response_code'
			response_time_graph
		end
	end
end.run(log: 'target/reports/go-perf.log', jtl: 'target/jmeter/go-perf.jtl')
