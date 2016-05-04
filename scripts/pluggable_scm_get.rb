require 'rubygems'
require 'ruby-jmeter'

test do
  threads count: 10 do
       get name: "show", url: "http://#{ARGV[0]}:8153/go/api/admin/materials/scms/github"
           header({name: 'Accept', value: 'application/vnd.go.cd.v1+json'})
  end
end.run(log: 'target/reports/scm_show.log', jtl: 'target/jmeter/scm_show.jtl')

