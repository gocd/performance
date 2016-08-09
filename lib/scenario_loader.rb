require './lib/scenario'
require 'ruby-jmeter'
require './lib/configuration'

class ScenarioLoader
  attr_reader :path

  def initialize(path)
    @path = path
    @scenarios_cache = {}
  end

  def run(name, base_url)
    setup = Configuration::SetUp.new 
    reports_dir = "reports/#{name}"
    FileUtils.mkdir_p reports_dir

    test do
      parse("#{name}.scenario").list.each do |scenario|
        threads scenario.threads do
          visit name: scenario.name, url: base_url + scenario.url
          assert equals: scenario.response_code, test_field: 'Assertion.response_code'
        end
      end
    end.run(path: setup.jmeter_bin,
            file: "#{reports_dir}/jmeter.jmx",
            log: "#{reports_dir}/jmeter.log",
            jtl: "#{reports_dir}/jmeter.jtl",
            properties: {"jmeter.save.saveservice.output_format" => "xml"}, gui: false)
  end

  private 

  def parse(scenario_file)
    scenarios("#{@path}/#{scenario_file}")
  end
end

