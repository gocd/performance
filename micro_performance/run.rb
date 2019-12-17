require './lib/downloader'
require './lib/gocd/pipeline'
require './micro_performance/lib/server_entities'
require './micro_performance/lib/go_constants'
require 'ruby-jmeter'
require 'rake'
require 'rest-client'
require 'json'
require 'parallel'
require 'process_builder'
require 'pry'
include FileUtils
include GoCD


def read_configuration
    configuration = JSON.parse(File.read('micro_performance/configuration.json'))
    File.open(".env","w") do |f|
      f.puts("TOTAL_PIPELINES=#{configuration['pipelines']['count']}")
      f.puts("STATIC_AGENTS=#{configuration['agents']['static']['count']}")
      f.puts("PERF_TEST_DURATION=#{configuration['test_duration']}")
      f.puts("GOCD_SERVER_IMAGE=#{configuration['gocd_server_image_name']}")
    end
end

def setup_server
    Server::Entities.new('micro_performance/configuration.json').create
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
        post name: 'Security Check', url: "#{GoConstants::BASE_URL}/auth/security_check",
              fill_in: { j_username: "admin",j_password: "badger" }
      end
      loops count: 1 do
          header(name: 'Accept', value: 'application/vnd.go.cd+json')
          visit name: scenario['name'], url: "#{GoConstants::BASE_URL}/#{scenario['url']}" do
            assert equals: scenario['response_code'], test_field: 'Assertion.response_code'
          end
      end
    end
  end.jmx(path: "tools/apache-jmeter-5.1.1/bin",
          file: "#{reports_dir}/jmeter.jmx")
end

def cleanup_perf_setup
    ['perf_db', 'perf_server', 'perf_agents', 'perf_repos', 'cadvisor'].each do |container|
      FileUtils.sh "docker rm -f -v #{container} || true"
    end

    ['config', 'logs', 'plugins', 'artifacts', 'db'].each do |fldr|
        FileUtils.rm_rf "micro_performance/server_setup/#{fldr}" if Dir.exist? "micro_performance/server_setup/#{fldr}"
    end
end

def about_page
  RestClient.get "#{GoConstants::BASE_URL}/about", Authorization: GoConstants::AUTH_HEADER do |response, _request, _result|
      p "Server ping failed with response code #{response.code} and message #{response.body}" unless response.code == 200
      return response
  end
end

def create_pipeline(data)
  RestClient.post("#{GoConstants::BASE_URL}/api/admin/pipelines",
      data,
      accept: 'application/vnd.go.cd+json',
      content_type: 'application/json', Authorization: GoConstants::AUTH_HEADER)
end


def start_compose
  FileUtils.sh ('docker-compose -f micro_performance/docker-compose.yml up > compose.log 2>&1 &')
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
  configuration = JSON.parse(File.read('micro_performance/configuration.json'))
  scenarios = configuration['scenarios']
  Parallel.each(scenarios, in_threads: scenarios.count) do |scenario|
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

puts "1) Run perf test from scratch
2) Cleanup all components created by performance script(including docker images)
3) Start docker compose and bring up the perf setup
4) Setup Jmeter
5) Sertup pipeline and other entities on already running server
6) Execute perf test on already running server
Enter your choice: "
input = gets.chomp
if input == '1'
  cleanup_perf_setup
  read_configuration
  start_compose
  setup_jmeter
  setup_server
  execute_load
elsif input == '2'
  cleanup_perf_setup
elsif input == '3'
  read_configuration
  start_compose
elsif input == '4'
  setup_jmeter
elsif input == '5'
  setup_server
elsif input == '6'
  execute_load
else
  p "No choice selected. Doing nothing"
end
