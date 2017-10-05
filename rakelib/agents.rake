require 'rest-client'
require 'json'
require './lib/gocd'
require './lib/downloader'
require './lib/configuration'
require './lib/looper'
require 'parallel'

namespace :agents do
  setup = Configuration::SetUp.new
  gocd_server = Configuration::Server.new
  gocd_client = GoCD::Client.new gocd_server.url

  task :prepare => 'agents:stop' do
    v, b = setup.go_version

    agents_dir = setup.agents_install_dir
    Parallel.each(setup.agents, :in_processes => 5) {|name|
      rm_rf "#{agents_dir}/#{name}/"
    }
    mkdir_p agents_dir

    Downloader.new(agents_dir) {|q|
      q.add "http://#{gocd_server.host}:#{gocd_server.port}/go/admin/agent.jar"
      %w{tfs-impl.jar agent-plugins.zip}.each{|file|
        q.add "http://#{gocd_server.host}:#{gocd_server.port}/go/admin/#{file}"
      }
    }.start

    Parallel.each(setup.agents, :in_processes => 5) {|name|
      mkdir_p "#{agents_dir}/#{name}/libs"
      %w{agent.jar tfs-impl.jar agent-plugins.zip}.each{|file|
        cp_r "#{agents_dir}/#{file}" , "#{agents_dir}/#{name}/"
      }
      cp "scripts/logback-gelf-1.0.4.jar", "#{agents_dir}/#{name}/libs/"
    }

  end

  task :start => ['agents:stop', 'server:auto_register'] do
    agent_config = Configuration::Agent.new
    puts 'Calling all agents'
    Parallel.each(setup.agents, :in_processes => 5) { |name|
      agent_dir = "#{setup.agents_install_dir}/#{name}"
      mkdir_p "#{agent_dir}/config/"
      cp_r "scripts/autoregister.properties" ,  "#{agent_dir}/config/autoregister.properties"
      logback_file = "#{agent_dir}/config/agent-logback.xml"
      cp_r "scripts/agent-logback.xml" ,  logback_file
      if agent_config.should_enable_debug_logging

        xml = @nokogiri::XML File.read(logback_file)
        agent_config.loggers.split(",").each{|logger_name|
          new_logger = "<logger name='#{logger_name}' level='DEBUG'>
                          <appender-ref ref='GrayLogAppender'/>
                        </logger>"
          xml.xpath('//configuration').first.add_child new_logger
        }
        xml.xpath('//configuration/appender/layout/originhost').first.content = name
        File.open(logback_file, "w") {|file| file.puts xml }
      end
      cd agent_dir do
        sh %{java #{agent_config.startup_args} -jar agent.jar -serverUrl https://#{gocd_server.host}:#{gocd_server.secure_port}/go > #{name}.log 2>&1 & }, verbose:false
        sleep 20
      end
    }
    Looper::run({interval:10, times:120}) {
      break if gocd_client.get_agents_count >= setup.agents.length
    }
    if gocd_client.get_agents_count < setup.agents.length
      raise "All agents are not up as expected. Expected agents #{setup.agents.length} and actual is #{gocd_client.get_agents_count}"
    end
    puts 'All agents running'
  end

  task :stop do
    verbose false do
      sh %{ pkill -f #{gocd_server.host} } do |ok, res|
        puts 'Stopped all agents' if ok
      end
    end
  end

  task :monitor do
    Looper::run({interval:300, times:setup.load_test_duration.to_i/300}) {
      response = RestClient.get("#{gocd_server.url}/api/agents", {accept: "application/vnd.go.cd.v4+json", Authorization: "Basic #{Base64.encode64(['perf_tester', ENV['LDAP_USER_PWD']].join(':'))}"})
      JSON.parse(response.body)['_embedded']['agents'].each{|agent|
        raise "Agents went missing" if ['Missing', 'LostContact'].include?(agent['agent_state'])
      }
    }
  end
end
