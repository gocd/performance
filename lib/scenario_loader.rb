require './lib/scenario'
require 'ruby-jmeter'
require './lib/configuration'

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
    generate_report(reports_dir, 'ResponseTimesDistribution')
  end

  def generate_report(reports_dir, type)
    process = ProcessBuilder.build('java', 
                                   '-jar',
                                   "#{@setup.jmeter_dir}/lib/ext/CMDRunner.jar",
                                   '--tool',
                                   'Reporter',
                                   '--generate-png',
                                   "#{reports_dir}/#{type}.png",
                                   '--input-jtl',
                                   "#{reports_dir}/jmeter.jtl",
                                   '--plugin-type',
                                   type)
    Process.wait(process.spawn)
  end
end

