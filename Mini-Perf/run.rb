require './lib/downloader'
require './lib/gocd/pipeline'
require 'ruby-jmeter'
require 'rake'
require 'rest-client'
require 'json'
require 'parallel'
require 'process_builder'
require 'pry'
include FileUtils
include GoCD

@auth_header = "Basic #{Base64.encode64('admin:badger')}"
@base_url = 'http://localhost:8153/go'

def populate_variables
    configuration = JSON.parse(File.read('Mini-Perf/configuration.json'))
    @total_pipelines = configuration['total_pipelines'].to_i
    @total_agents = configuration['total_agents'].to_i
    @test_duration = configuration['test_duration'].to_i
    File.open(".env","w") do |f|
      f.puts("TOTAL_PIPELINES=#{configuration['total_pipelines']}")
      f.puts("TOTAL_AGENTS=#{configuration['total_agents']}")
      f.puts("PERF_TEST_DURATION=#{configuration['test_duration']}")
    end
    @scenarios = configuration['scenarios']
end

def setup_server
    create_pipelines
end

def create_pipelines
  (1..@total_pipelines).each do |pipeline|
      performance_pipeline = Pipeline.new(group: 'performance', name: "go-perf-#{pipeline}") do |p|
          p << GitMaterial.new(name: 'material', url: "git://repos/git-repo-#{pipeline}", destination: 'git-repo')

          p << Stage.new(name: 'first') do |s|
              s << Job.new(name: 'firstJob') do |j|
              j << ExecTask.new(command: 'ls')
              end
          end

        p << Stage.new(name: 'second') do |s|
          s << Job.new(name: 'secondJob') do |j|
            j << ExecTask.new(command: 'ls')
          end
        end
      end

      begin
        create_pipeline(performance_pipeline.to_json)
      rescue StandardError => e
        raise "Something went wrong while creating pipeline #{pipeline}. \n Server says:\n #{e.response}"
      end
  end
end

def setup_jmeter
    rm_rf "tools" if Dir.exist? "tools"
    mkdir_p "tools"
    puts 'Downloading and setting up JMeter'
    Downloader.new("tools") do |q|
    q.add 'https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-5.1.1.zip'
    end.start do |file|
        file.extract_to("tools")
    end

    puts 'Downloading and setting up JMeter plugins'
    Downloader.new("tools") do |q|
        q.add 'https://jmeter-plugins.org/downloads/file/JMeterPlugins-Standard-1.4.0.zip'
        q.add 'https://jmeter-plugins.org/downloads/file/JMeterPlugins-Extras-1.4.0.zip'
        q.add 'https://jmeter-plugins.org/downloads/file/JMeterPlugins-ExtrasLibs-1.4.0.zip'
    end.start do |plugin_file|
        plugin_file.extract_to("tools/apache-jmeter-5.1.1")
    end
    chmod '+x', "tools/apache-jmeter-5.1.1/bin/jmeter"
end

def create_jmx(scenario)
  reports_dir = "reports/#{scenario['name']}"
  rm_rf reports_dir if Dir.exist? reports_dir
  FileUtils.mkdir_p reports_dir

  test do
    cookies
    cache
    with_browser :chrome
    threads count: scenario['thread_count'], rampup: scenario['rampup'], duration: scenario['duration'] do
      constant_throughput_timer value: scenario['throughput'], calcMode: 4
      Once do
        post name: 'Security Check', url: "#{@base_url}/go/auth/security_check",
              fill_in: { j_username: "admin",j_password:"badger" }
      end
      loops count: 1 do
          header(name: 'Accept', value: 'application/vnd.go.cd+json')
          visit name: scenario['name'], url: "#{@base_url}/#{actual_url(scenario['url'])}" do ##{actual_url(url_value)}
            assert equals: scenario['response_code'], test_field: 'Assertion.response_code'
          end
      end
    end
  end.jmx(path: "tools/apache-jmeter-5.1.1/bin",
          file: "#{reports_dir}/jmeter.jmx",
          log: "#{reports_dir}/jmeter.log",
          jtl: "#{reports_dir}/jmeter.jtl",
          properties: { 'jmeter.save.saveservice.output_format' => 'xml' }, gui: false)
end

def cleanup_perf_setup
    FileUtils.sh 'docker rm -f $(docker ps -q -a) || true'
    FileUtils.sh ('docker rmi -f $(docker images -q) || true')
    FileUtils.sh ('docker volume rm -f $(docker volume ls -q) || true')

    ['config', 'logs', 'plugins', 'artifacts', 'db'].each do |fldr|
        FileUtils.rm_rf "Mini-Perf/server_setup/#{fldr}" if Dir.exist? "Mini-Perf/server_setup/#{fldr}"
    end
end

def actual_url(tmp)
  begin
    Timeout.timeout(60) do
      loop do
        pipeline = "go-perf-#{rand(1..@total_pipelines)}"
        pipeline_count = get_pipeline_count(pipeline)
        break if pipeline_count != 'retry'
        sleep 10
      end
    end
  rescue Timeout::Error
    pipeline_count = 1
  end
  agent = get_agent_id(rand(1..@total_agents))
  format(tmp, pipeline: pipeline, pipelinecount: pipeline_count, comparewith: pipeline_count - 1, stage: 'default', stagecount: '1', job: 'defaultJob', jobcount: '1', agentid: agent)
end

def get_pipeline_count(name)
  history = JSON.parse(open("#{@base_url}/api/pipelines/#{name}/history/0", 'Confirm' => 'true', http_basic_authentication: ['admin', 'badger']).read)
  begin
    history['pipelines'][0]['counter']
  rescue StandardError => e
    'retry'
  end
end

def get_agent_id(idx)
  response = JSON.parse(open("#{@base_url}/api/agents", 'Accept' => 'application/vnd.go.cd+json', http_basic_authentication: ['admin', 'badger'], read_timeout: 300).read)
  all_agents = response['_embedded']['agents']
  all_agents.map { |a| a['uuid'] unless a.key?('elastic_agent_id') }.compact[idx - 1] # pick only the physical agents, elastic agents are not long living
end

def about_page
  RestClient.get "#{@base_url}/about", Authorization: @auth_header do |response, _request, _result|
      p "Server ping failed with response code #{response.code} and message #{response.body}" unless response.code == 200
      return response
  end
end

def create_pipeline(data)
  RestClient.post("#{@base_url}/api/admin/pipelines",
      data,
      accept: 'application/vnd.go.cd+json',
      content_type: 'application/json', Authorization: @auth_header)
end


def start_compose
  FileUtils.sh ('docker-compose -f Mini-perf/docker-compose.yml up > compose.log 2>&1 &')
  puts 'Waiting for server start up'
  Timeout.timeout(600) do
    loop do
      begin
        sleep 10
        if about_page.code == 200
          break
        end
      rescue StandardError
      end
    end
  end
end

def generate_reports(reports_dir)
  types = %w[ResponseTimesDistribution ResponseTimesPercentiles ResponseCodesPerSecond HitsPerSecond]
  types.each do |type_of_graph|
    generate_report(reports_dir, type_of_graph, 'png')
    generate_report(reports_dir, type_of_graph, 'csv')
  end
end

def generate_report(reports_dir, type_of_graph, type_of_report)
  process = ProcessBuilder.build('java',
                                 '-jar',
                                 "tools/apache-jmeter-5.1.1/lib/ext/CMDRunner.jar",
                                 '--tool',
                                 'Reporter',
                                 "--generate-#{type_of_report}",
                                 "#{reports_dir}/#{type_of_graph}.#{type_of_report}",
                                 '--input-jtl',
                                 "#{reports_dir}/jmeter.jtl",
                                 '--plugin-type',
                                 type_of_graph)
  Process.wait(process.spawn)
end


def execute_load
  Parallel.each(@scenarios, in_threads: @scenarios.count) do |scenario|
    create_jmx(scenario)
    process = ProcessBuilder.build('tools/apache-jmeter-5.1.1/bin/jmeter',
                                    '-n',
                                    "-t",
                                    "reports/#{scenario['name']}/jmeter.jmx",
                                    '-l',
                                    "reports/#{scenario['name']}/jmeter.jtl")
    Process.wait(process.spawn)
    generate_reports("reports/#{scenario['name']}")
  end
end


# cleanup_perf_setup
 populate_variables
# start_compose
# setup_jmeter
# setup_server
# # Need some warm ups here -  to get the pipelines run at least once
# sleep 300
execute_load
