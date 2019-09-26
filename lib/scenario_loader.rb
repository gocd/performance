require './lib/scenario'
require 'ruby-jmeter'
require './lib/configuration'
require './lib/analyzer'
require 'nokogiri'
require 'fileutils'
require 'pry'
require 'json'
include FileUtils

module RubyJmeter
  class BackendListener
    attr_accessor :doc
    include Helper

    def initialize(params = {})
      @doc = Nokogiri::XML(<<-EOS.strip_heredoc)
      <BackendListener guiclass="BackendListenerGui" testclass="BackendListener" testname="Backend Listener" enabled="true">
        <elementProp name="arguments" elementType="Arguments" guiclass="ArgumentsPanel" testclass="Arguments" enabled="true">
          <collectionProp name="Arguments.arguments">
            <elementProp name="graphiteMetricsSender" elementType="Argument">
              <stringProp name="Argument.name">graphiteMetricsSender</stringProp>
              <stringProp name="Argument.value">org.apache.jmeter.visualizers.backend.graphite.TextGraphiteMetricsSender</stringProp>
              <stringProp name="Argument.metadata">=</stringProp>
            </elementProp>
            <elementProp name="graphiteHost" elementType="Argument">
              <stringProp name="Argument.name">graphiteHost</stringProp>
              <stringProp name="Argument.value">#{params[:db_host]}</stringProp>
              <stringProp name="Argument.metadata">=</stringProp>
            </elementProp>
            <elementProp name="graphitePort" elementType="Argument">
              <stringProp name="Argument.name">graphitePort</stringProp>
              <stringProp name="Argument.value">2003</stringProp>
              <stringProp name="Argument.metadata">=</stringProp>
            </elementProp>
            <elementProp name="rootMetricsPrefix" elementType="Argument">
              <stringProp name="Argument.name">rootMetricsPrefix</stringProp>
              <stringProp name="Argument.value">#{params[:prefix]}</stringProp>
              <stringProp name="Argument.metadata">=</stringProp>
            </elementProp>
            <elementProp name="summaryOnly" elementType="Argument">
              <stringProp name="Argument.name">summaryOnly</stringProp>
              <stringProp name="Argument.value">true</stringProp>
              <stringProp name="Argument.metadata">=</stringProp>
            </elementProp>
            <elementProp name="samplersList" elementType="Argument">
              <stringProp name="Argument.name">samplersList</stringProp>
              <stringProp name="Argument.value">#{params[:samplers_list]}</stringProp>
              <stringProp name="Argument.metadata">=</stringProp>
            </elementProp>
            <elementProp name="percentiles" elementType="Argument">
              <stringProp name="Argument.name">percentiles</stringProp>
              <stringProp name="Argument.value">90;95;99</stringProp>
              <stringProp name="Argument.metadata">=</stringProp>
            </elementProp>
          </collectionProp>
        </elementProp>
        <stringProp name="classname">org.apache.jmeter.visualizers.backend.graphite.GraphiteBackendListenerClient</stringProp>
      </BackendListener>)
      EOS
      update params
      update_at_xpath params if params.is_a?(Hash) && params[:update_at_xpath]
    end
  end

  class ExtendedDSL < DSL
    def backend_listener(*args, &block)
      params = args.shift || {}
      node = RubyJmeter::BackendListener.new(params)
      attach_node(node, &block)
    end
  end
end

class ScenarioLoader
  attr_reader :path

  def initialize(path)
    @path = path
    @scenarios_cache = {}
    @setup = Configuration::SetUp.new
  end

  def run(name, base_url, spike = false)
    reports_dir = "reports/#{name}"
    throughput = @setup.throughput_per_minute
    FileUtils.mkdir_p reports_dir

    test do
      parse("#{name}.scenario").list.each do |scenario|
        cookies
        cache
        with_browser :chrome
        @setup.thread_groups.each do |_tg|
          threads scenario.threads do
            constant_throughput_timer value: throughput, calcMode: 4
            synchronizing_timer groupSize: 100 if spike == true
            Once do
              post name: 'Security Check', url: "#{base_url}/auth/security_check",
                   fill_in: { j_username: "file_based_user",j_password:"#{ENV['FILE_BASED_USER_PWD']}" }
            end
            scenario.loops.each do |jloop|
              loops jloop.loopcount do
                jloop.url_list.each do |url_value|
                  header(name: 'Accept', value: scenario.version) unless scenario.version.nil?
                  visit name: scenario.name, url: "#{base_url}#{jloop.actual_url(url_value)}" do
                    assert equals: scenario.response_code, test_field: 'Assertion.response_code'
                  end
                end
              end
            end
          end
        end
        #backend_listener prefix: "#{name}.", samplers_list: scenario.name.to_s, db_host: @setup.influxdb_host
      end
    end.run(path: @setup.jmeter_bin,
            file: "#{reports_dir}/jmeter.jmx",
            log: "#{reports_dir}/jmeter.log",
            jtl: "#{reports_dir}/jmeter.jtl",
            properties: { 'jmeter.save.saveservice.output_format' => 'xml' }, gui: false)
    generate_reports(reports_dir)
    assert_test(reports_dir)
  end

  def run_with_access_token(name, base_url, spike = false)
    reports_dir = "reports/#{name}"
    throughput = @setup.throughput_per_minute
    FileUtils.mkdir_p reports_dir

    test do
      parse("#{name}.scenario").list.each do |scenario|
        @setup.thread_groups.each do |_tg|
          threads scenario.threads do
            constant_throughput_timer value: throughput, calcMode: 4
            synchronizing_timer groupSize: 100 if spike == true
            Once do
              header(name: 'Authorization', value: "Basic #{Base64.encode64(['file_based_user', ENV['FILE_BASED_USER_PWD']].join(':'))}".strip)
              header(name: 'Accept', value: "application/vnd.go.cd.v1+json")
              header(name: 'Content-Type', value: "application/json")
              post name: 'Get Access Token', url: "#{base_url}/api/current_user/access_tokens", raw_body: { description: "perf testing" }.to_json do
                extract name: 'access_token', regex: %q{.*"token" : "([^"]+)".*}
              end
            end
            scenario.loops.each do |jloop|
              loops jloop.loopcount do
                jloop.url_list.each do |url_value|
                  header(name: 'Accept', value: scenario.version) unless scenario.version.nil?
                  header(name: 'Authorization', value: "Bearer ${access_token}")
                  visit name: scenario.name, url: "#{base_url}#{jloop.actual_url(url_value)}" do
                    assert equals: scenario.response_code, test_field: 'Assertion.response_code'
                  end
                end
              end
            end
          end
        end
      end
    end.run(path: @setup.jmeter_bin,
            file: "#{reports_dir}/jmeter.jmx",
            log: "#{reports_dir}/jmeter.log",
            jtl: "#{reports_dir}/jmeter.jtl",
            properties: { 'jmeter.save.saveservice.output_format' => 'xml' }, gui: false)
    generate_reports(reports_dir)
    assert_test(reports_dir)
  end


  def run_all(base_url, spike = false)
    reports_dir = 'reports/all'
    FileUtils.mkdir_p reports_dir

    test do
      Dir.glob("#{@path}/*.scenario") do |file|
        parse(File.basename(file)).list.each do |scenario|
          cookies
          cache
          with_browser :chrome
          @setup.thread_groups.each do |_tg|
            threads scenario.threads do
              constant_throughput_timer value: throughput, calcMode: 2
              synchronizing_timer groupSize: 100 if spike == true
              Once do
                post name: 'Security Check', url: "#{base_url}/auth/security_check",
                     raw_body: "j_username=file_based_user&j_password=#{ENV['FILE_BASED_USER_PWD']}"
              end
              scenario.loops.each do |jloop|
                loops jloop.loopcount do
                  jloop.url_list.each do |url_value|
                    visit name: scenario.name, url: "#{base_url}#{jloop.actual_url(url_value)}"
                    assert equals: scenario.response_code, test_field: 'Assertion.response_code'
                  end
                end
              end
            end
          end
        end
      end
    end.run(path: @setup.jmeter_bin,
            file: "#{reports_dir}/jmeter.jmx",
            log: "#{reports_dir}/jmeter.log",
            jtl: "#{reports_dir}/jmeter.jtl",
            properties: { 'jmeter.save.saveservice.output_format' => 'xml' }, gui: false)
    generate_reports(reports_dir)
    assert_test(reports_dir)
  end

  def spike(name, base_url)
    reports_dir = "reports/#{name}"
    FileUtils.mkdir_p reports_dir

    test do
      parse("#{name}.scenario").list.each do |scenario|
        @setup.thread_groups.each do |_tg|
          threads scenario.threads do
            synchronizing_timer groupSize: 100
            scenario.loops.each do |jloop|
              loops jloop.loopcount do
                jloop.url_list.each do |url_value|
                  visit name: scenario.name, url: "#{base_url}#{jloop.actual_url(url_value)}"
                  assert equals: scenario.response_code, test_field: 'Assertion.response_code'
                end
              end
            end
          end
        end
      end
    end.run(path: @setup.jmeter_bin,
            file: "#{reports_dir}/jmeter.jmx",
            log: "#{reports_dir}/jmeter.log",
            jtl: "#{reports_dir}/jmeter.jtl",
            properties: { 'jmeter.save.saveservice.output_format' => 'xml' }, gui: false)
    generate_reports(reports_dir)
    assert_test(reports_dir)
  end

  def monitor(name, host, base_url)
    reports_dir = "reports/#{name}"
    FileUtils.mkdir_p reports_dir

    test do
      step name: 'About page call using stepping thread group',
           total_threads: 10,
           initial_delay: 10,
           start_threads: 1,
           add_threads: 1,
           start_every: 1,
           stop_threads: 1,
           stop_every: 1,
           flight_time: @setup.load_test_duration,
           rampup: 1 do
        visit name: 'About page', url: "#{base_url}about"
      end
      perfmon_collector name: 'Perfmon Metrics Collector',
                        nodes: [{
                          server: host.to_s,
                          port: 4444,
                          metric: 'JMX',
                          parameters: "url=#{host}\\:4711:gc-time"
                        }, {
                          server: host.to_s,
                          port: 4444,
                          metric: 'JMX',
                          parameters: "url=#{host}\\:4711:memory-usage"
                        }, {
                          server: host.to_s,
                          port: 4444,
                          metric: 'CPU',
                          parameters: 'name=node#1:label=cpu-node'
                        }],
                        filename: "#{reports_dir}/jmeter.jtl",
                        xml: true
    end.run(path: @setup.jmeter_bin,
            file: "#{reports_dir}/jmeter.jmx",
            log: "#{reports_dir}/jmeter.log",
            properties: { 'jmeter.save.saveservice.output_format' => 'xml' }, gui: false)
    generate_perfmon_report(reports_dir)
  end

  private

  def parse(scenario_file)
    scenarios("#{@path}/#{scenario_file}")
  end

  def generate_perfmon_report(reports_dir)
    generate_report(reports_dir, 'PerfMon', 'png')
    generate_report(reports_dir, 'PerfMon', 'csv')

    consolidate_reports reports_dir
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

  def assert_test(reports_dir)
    raise 'HTTP Response assertion failed more than the tolerable level, Please check the reports' unless Analyzers::ResultAnalyzer.new("#{reports_dir}/jmeter.jtl").tolerable?
  end

  def consolidate_reports(reports_dir)
    builder = Nokogiri::HTML::Builder.new do |doc|
      doc.html do
        doc.body do
          cd reports_dir do
            Dir.glob('*.png') do |file|
              title = File.basename(file, '.*')
              doc.img src: file, alt: title, title: title
            end
          end
        end
      end
    end
    open("#{reports_dir}/index.html", 'w') do |file|
      file << builder.to_html
    end
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
end
