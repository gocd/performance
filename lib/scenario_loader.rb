require './lib/scenario'
require 'ruby-jmeter'
require './lib/configuration'
require 'nokogiri'
require 'fileutils'
include FileUtils

class ScenarioLoader
  attr_reader :path

  def initialize(path)
    @path = path
    @scenarios_cache = {}
    @setup = Configuration::SetUp.new 
  end

  def run(name, base_url)
    reports_dir = "reports/#{name}"
    FileUtils.mkdir_p reports_dir

    test do
      parse("#{name}.scenario").list.each do |scenario|
        threads scenario.threads do
          visit name: scenario.name, url: base_url + scenario.url
          assert equals: scenario.response_code, test_field: 'Assertion.response_code'
        end
      end
    end.run(path: @setup.jmeter_bin,
            file: "#{reports_dir}/jmeter.jmx",
            log: "#{reports_dir}/jmeter.log",
            jtl: "#{reports_dir}/jmeter.jtl",
            properties: {"jmeter.save.saveservice.output_format" => "xml"}, gui: false)
    generate_reports(reports_dir)
  end

  private 

  def parse(scenario_file)
    scenarios("#{@path}/#{scenario_file}")
  end

  def generate_reports(reports_dir)
    types = %w(ResponseTimesDistribution ResponseTimesOverTime ResponseTimesPercentiles ResponseCodesPerSecond PerfMon ThreadsStateOverTime BytesThroughputOverTime HitsPerSecond ThroughputVsThreads TimesVsThreads)
    types.each do |type_of_graph|
      generate_report(reports_dir, type_of_graph, 'png')
      generate_report(reports_dir, type_of_graph, 'csv')
    end
    ['AggregateReport', 'SynthesisReport'].each do |type|
      generate_report(reports_dir, type, 'csv')
    end
    consolidate_reports reports_dir 
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
