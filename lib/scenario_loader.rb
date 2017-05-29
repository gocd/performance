require './lib/scenario'
require 'ruby-jmeter'
require './lib/configuration'
require './lib/analyze_result'
require 'nokogiri'
require 'fileutils'
require 'pry'
include FileUtils

class ScenarioLoader
  attr_reader :path

  def initialize(path)
    @path = path
    @scenarios_cache = {}
    @setup = Configuration::SetUp.new
  end

  def run(name, base_url, spike=false)
    reports_dir = "reports/#{name}"
    FileUtils.mkdir_p reports_dir

    test do
      parse("#{name}.scenario").list.each do |scenario|
        @setup.thread_groups.each do |tg|
          threads scenario.threads do
            constant_throughput_timer value: 30.0
            synchronizing_timer groupSize: 100 if spike == true
            cookies
            cache
            with_browser :chrome
            post name: 'Security Check', url: "#{base_url}/auth/security_check",
                raw_body: 'j_username=admin&j_password=badger'
            scenario.loops.each do |jloop|
              loops jloop.loopcount do
                jloop.url_list.each do |url_value|
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
            properties: {"jmeter.save.saveservice.output_format" => "xml"}, gui: false)
    generate_reports(reports_dir)
    assert_test(reports_dir)
  end

  def run_all(base_url)
    reports_dir = "reports/all"
    FileUtils.mkdir_p reports_dir

    test do
      Dir.glob("#{@path}/*.scenario") do |file|
        parse(File.basename file).list.each do |scenario|
          @setup.thread_groups.each do |tg|
            threads scenario.threads do
              constant_throughput_timer value: 30.0
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
            properties: {"jmeter.save.saveservice.output_format" => "xml"}, gui: false)
    generate_reports(reports_dir)
    assert_test(reports_dir)
  end

  def spike(name, base_url)
    reports_dir = "reports/#{name}"
    FileUtils.mkdir_p reports_dir

    test do
      parse("#{name}.scenario").list.each do |scenario|
        @setup.thread_groups.each do |tg|
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
            properties: {"jmeter.save.saveservice.output_format" => "xml"}, gui: false)
    generate_reports(reports_dir)
    assert_test(reports_dir)
  end

  def monitor(name, host, base_url)
    reports_dir = "reports/#{name}"
    FileUtils.mkdir_p reports_dir

    test do
      step  name: 'About page call using stepping thread group',
        total_threads: 10,
        initial_delay: 10,
        start_threads: 1,
        add_threads: 1,
        start_every: 1,
        stop_threads: 1,
        stop_every: 1,
        flight_time: @setup.load_test_duration,
        rampup: 1 do
        visit name: "About page", url: "#{base_url}about"
      end
      perfmon_collector name: 'Perfmon Metrics Collector',
        nodes: [{
        server: "#{host}",
        port: 4444,
        metric: 'JMX',
        parameters: "url=#{host}\\:4711:gc-time"
      },{
        server: "#{host}",
        port: 4444,
        metric: 'JMX',
        parameters: "url=#{host}\\:4711:memory-usage"
      },{
        server: "#{host}",
        port: 4444,
        metric: 'CPU',
        parameters: 'name=node#1:label=cpu-node'
      }],
      filename: "#{reports_dir}/jmeter.jtl",
      xml: true
    end.run(path: @setup.jmeter_bin,
            file: "#{reports_dir}/jmeter.jmx",
            log: "#{reports_dir}/jmeter.log",
            properties: {"jmeter.save.saveservice.output_format" => "xml"}, gui: false)
    generate_perfmon_report(reports_dir)
  end

  private

  def parse(scenario_file)
    scenarios("#{@path}/#{scenario_file}")
  end

  def generate_perfmon_report(reports_dir)
    generate_report(reports_dir, "PerfMon", 'png')
    generate_report(reports_dir, "PerfMon", 'csv')

    consolidate_reports reports_dir
  end

  def generate_reports(reports_dir)
    types = %w(ResponseTimesDistribution ResponseTimesPercentiles ResponseCodesPerSecond HitsPerSecond)
    types.each do |type_of_graph|
      generate_report(reports_dir, type_of_graph, 'png')
      generate_report(reports_dir, type_of_graph, 'csv')
    end
    ['AggregateReport', 'SynthesisReport'].each do |type|
      generate_report(reports_dir, type, 'csv')
    end
    consolidate_reports reports_dir
  end

  def assert_test(reports_dir)
      raise "HTTP Response assertion failed more than the tolerable level, Please check the reports" unless AnalyzeResult.new("#{reports_dir}/jmeter.jtl").tolerable?()
  end

  def consolidate_reports(reports_dir)
    builder = Nokogiri::HTML::Builder.new do |doc|
      doc.html {
        doc.body {
          cd reports_dir do
            Dir.glob('*.png') do |file|
              title = File.basename(file, '.*')
              doc.img src: file, alt: title, title: title
            end
          end
        }
      }
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
