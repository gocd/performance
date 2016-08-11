require './lib/gocd'
require './lib/configuration'
require './lib/looper'
require 'ruby-jmeter'
require './lib/scenario_loader'
require 'process_builder'

namespace :performance do
  go_server = Configuration::Server.new
  setup = Configuration::SetUp.new 

  gocd_client = GoCD::Client.new go_server.url

  namespace :config do
    task :update do
      duration = setup.config_save_duration
      puts "Saving config by setting the job timeout in a loop #{duration}"
      Looper::run(duration) { 
        timeout = 60 + rand(9)

        puts "Setting job timeout to #{timeout}"
        gocd_client.job_timeout timeout
      } 
    end
  end

  namespace :git do
    task :update => 'git:daemon:start' do
      duration = setup.git_commit_duration

      Looper::run(duration) {
        setup.git_repos.each do |repo|
          verbose false do
            cd repo do
              time = Time.now
              File.write("file", time.to_f)
              sh("git add .;git commit -m 'This is commit at #{time.rfc2822}' --author 'foo <foo@bar.com>'")
            end
          end
        end
      }
    end
  end

  task :dashboard => 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.run 'dashboard', go_server.url
  end

  namespace :scenarios do
    task :run => 'jmeter:prepare' do
      test do
        scenarios = JSON.parse(File.read('scripts/load_scenarios.json'))
        scenarios.each do |key, scenario|
          test_url = go_server.url + scenario["url"]
          if scenario["name"] == "dashboard_api"
            threads count: scenario["count"], rampup: scenario["rampup"], duration: scenario["duration"] do
              get name: scenario["name"], url: test_url do
                scenario["header"].each do |header|
                  header({name: header["name"], value: header["value"]})
                end
                assert equals: scenario["response_code"], test_field: 'Assertion.response_code'
                extract json: '$._embedded.pipeline_groups[0]._embedded.pipelines[0]._links.settings_path.href',
                  name: 'general'
                extract json: '$._embedded.pipeline_groups[0]._embedded.pipelines[0]._links.self.href', 
                  name: 'history'
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

      end.run(path: setup.jmeter_bin,
              file: 'jmeter.jmx',
              log: 'jmeter.log',
              properties: {"jmeter.save.saveservice.output_format" => "xml"}, gui: false)
      # Add this to log response data -  "jmeter.save.saveservice.response_data" => "true" - expect logs to grow
    end
  end
end
