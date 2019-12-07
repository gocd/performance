require './lib/downloader'
require './lib/gocd/pipeline'
require 'ruby-jmeter'
require 'rake'
require 'rest-client'
require 'json'
include FileUtils
include GoCD

@auth_header = "Basic #{Base64.encode64('admin:badger')}"

def populate_variables
    configuration = JSON.parse(File.read('Mini-Perf/configuration.json'))
    ENV['TOTAL_PIPELINES'] = configuration['total_pipelines']
    ENV['TOTAL_AGETNS'] = configuration['total_agents']
    ENV['TEST_DURATION'] = configuration['test_duration']
    @scenarios = configuration['scenarios']
end

def setup_server
    create_pipelines
end

def create_pipelines
  (1..ENV['TOTAL_PIPELINES'].to_i).each do |pipeline|
      performance_pipeline = Pipeline.new(group: 'performance', name: "go-perf-#{pipeline}") do |p|
          p << GitMaterial.new(name: 'material1', url: "git://repos/git-repo-#{pipeline}", destination: 'git-repo')

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
    rm_rf "tools" if Dir.exist("tools")
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
end

def execute(scenario)
  reports_dir = "reports/#{scenario['name']}"
  rm_rf reports_dir if Dir.exist? reports_dir
  FileUtils.mkdir_p reports_dir

  test do
    cookies
    cache
    with_browser :chrome
    (1..scenario['thread_groups']).each do |_tg|
      threads count: scenario['thread_count'], rampup: scenario['rampup'], duration: ENV['TEST_DURATION'] do
        constant_throughput_timer value: scenario['throughput'], calcMode: 4
        Once do
          post name: 'Security Check', url: "http://localhost:8153/go/auth/security_check",
                fill_in: { j_username: "admin",j_password:"badger" }
        end
        loops 1 do
            header(name: 'Accept', value: 'application/vnd.go.cd+json')
            visit name: scenario['name'], url: "http://localhost:8153/go/#{actual_url(url_value)}" do
              assert equals: scenario['response_code'], test_field: 'Assertion.response_code'
            end
        end
      end
    end
  end.run(path: "tools/apache-jmeter-5.1.1/bin",
          file: "#{reports_dir}/jmeter.jmx",
          log: "#{reports_dir}/jmeter.log",
          jtl: "#{reports_dir}/jmeter.jtl",
          properties: { 'jmeter.save.saveservice.output_format' => 'xml' }, gui: false)
  generate_reports(reports_dir)
end

def cleanup_perf_setup
    FileUtils.sh 'docker rm -f $(docker ps -q -a) || true'
    FileUtils.sh ('docker rmi -f $(docker images -q) || true')
    FileUtils.sh ('docker volume rm -f $(docker volume ls -q) || true')

    ['config', 'logs', 'plugins', 'artifacts', 'db'].each do |fldr|
        FileUtils.rm_rf "server_setup/#{fldr}" if Dir.exist? "server_setup/#{fldr}"
    end
end

def actual_url(tmp)
  pipeline_count = ''
  pipeline = ''
  begin
    Timeout.timeout(60) do
      loop do
        pipeline = "go-perf-#{rand(ENV['TOTAL_PIPELINES'].to_i)}"
        pipeline_count = get_pipeline_count(pipeline)
        break if pipeline_count != 'retry'
        sleep 10
      end
    end
  rescue Timeout::Error
    pipeline_count = 1
  end
  agent = @gocd_client.get_agent_id(rand(@setup.agents.length))
  format(tmp, pipeline: pipeline, pipelinecount: pipeline_count, comparewith: pipeline_count - 1, stage: 'default', stagecount: '1', job: 'defaultJob', jobcount: '1', agentid: agent)
end

def get_pipeline_count(name)
  history = JSON.parse(open("http://localhost:8153/go/api/pipelines/#{name}/history/0", 'Confirm' => 'true', http_basic_authentication: @auth_header).read)
  begin
    history['pipelines'][0]['counter']
  rescue StandardError => e
    'retry'
  end
end

def get_agent_id(idx)
  response = JSON.parse(open("http://localhost:8153/go/api/agents", 'Accept' => 'application/vnd.go.cd+json', http_basic_authentication: @auth_header, read_timeout: 300).read)
  all_agents = response['_embedded']['agents']
  all_agents.map { |a| a['uuid'] unless a.key?('elastic_agent_id') }.compact[idx - 1] # pick only the physical agents, elastic agents are not long living
end

def about_page
  RestClient.get "http://localhost:8153/go/about", Authorization: @auth_header do |response, _request, _result|
      p "Server ping failed with response code #{response.code} and message #{response.body}" unless response.code == 200
      return response
  end
end

def create_pipeline(data)
  RestClient.post("http://localhost:8153/go/api/admin/pipelines",
      data,
      accept: 'application/vnd.go.cd+json',
      content_type: 'application/json', Authorization: @auth_header)
end


def start_compose
  FileUtils.sh ('docker-compose -f Mini-perf/docker-compose.yml up > compose.log 2>&1 &')
  puts 'Waiting for server start up'
  server_is_running = false
  Timeout.timeout(60) do
    loop do
      begin
        if about_page.code == 200
          server_is_running = true
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
  %w[AggregateReport SynthesisReport].each do |type|
    generate_report(reports_dir, type, 'csv')
  end
  consolidate_reports reports_dir
end

def generate_report(reports_dir, type_of_graph, type_of_report)
  process = ProcessBuilder.build('java',
                                 '-jar',
                                 "#{@setup.jmeter_dir}/lib/ext/CMDRunner.jar",
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

#cleanup_perf_setup
#start_compose
populate_variables
#setup_jmeter
setup_server
#execute
