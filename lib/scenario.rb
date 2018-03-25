require 'pry'
require './lib/configuration'
require './lib/looper'

class Scenario
  def initialize
    @setup = Configuration::SetUp.new
    @name = ''
    @url = ''
    @count = @setup.thread_count
    @rampup = @setup.users_rampup_time
    @duration = @setup.load_test_duration
    @response_code = 200
    @loops = []
  end

  def method_missing(method_name, *arguments, &block)
    property = "@#{method_name}"
    if defined?(property)
      if arguments.length == 1
        instance_variable_set property, arguments.first
      else
        return instance_variable_get property
      end
    else
      super(method_name, *arguments, &block)
    end
  end

  def threads
    { count: @count, rampup: @rampup, duration: @duration }
  end

  def add(loop)
    @loops << loop
  end

  def loop(&block)
    instance = Loop.new
    instance.instance_eval(&block)
    add(instance)
  end
end

class Loop
  attr_reader :url_list

  def initialize
    @loopcount = 1
    @url_list = []
    @setup = Configuration::SetUp.new
    @server = Configuration::Server.new
    @gocd_client = GoCD::Client.new @server.url
  end

  def url(arg)
    @url_list << arg
  end

  def count(arg)
    @loopcount = arg
  end

  def loopcount
    { count: @loopcount }
  end

  def actual_url(tmp)
    pipeline_count = ''
    pipeline = ''
    begin
      Timeout.timeout(60) do
        loop do
          pipeline = @setup.pipelines[rand(@setup.pipelines.length)]
          pipeline_count = @gocd_client.get_pipeline_count(pipeline)
          break if pipeline_count != 'retry'
          sleep 10
        end
      end
    rescue Timeout::Error
      pipeline_count = 1
    end
    agent = @gocd_client.get_agent_id(rand(@setup.agents.length))
    format(tmp, pipeline: pipeline, pipelinecount: pipeline_count, comparewith: pipeline_count - 1, stage: 'default', stagecount: '1', job: 'default_job', jobcount: '1', agentid: agent)
  end
end

class Scenarios
  attr_reader :list

  def initialize
    @list = []
  end

  def add(scenario)
    @list << scenario
  end

  def scenario(&block)
    instance = Scenario.new
    instance.instance_eval(&block)
    add(instance)
  end
end

def scenarios(file)
  instance = Scenarios.new
  instance.instance_eval IO.read(file)
  instance
end
