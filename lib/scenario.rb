class Scenario

  def initialize
    @name = ''
    @url = ''
    @count = 1
    @rampup = 1
    @duration = 30
    @response_code = 200
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
  return instance
end
