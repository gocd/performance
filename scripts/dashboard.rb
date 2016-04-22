require 'rubygems'
require 'ruby-jmeter'

test do 
	threads count: 10 do
		visit name: 'Go Page', url: "http://#{ARGV[0]}:8153/go/pipelines"
	end
end.run(log: 'target/reports/dashboard.log', jtl: 'target/jmeter/dashboard.jtl')
