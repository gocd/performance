require 'rest-client'
require 'json'
require './lib/gocd'
require './lib/downloader'
require './lib/configuration'
require './lib/looper'

namespace :agents do
  setup = Configuration::SetUp.new
  gocd_server = Configuration::Server.new
  gocd_client = GoCD::Client.new gocd_server.url

  task :prepare => 'agents:stop' do
    v, b = setup.go_version

    agents_dir = setup.agents_install_dir
    rm_rf agents_dir
    mkdir_p agents_dir

    Downloader.new(agents_dir) {|q|
      q.add "http://#{gocd_server.host}:#{gocd_server.port}/go/admin/agent.jar"
      %w{tfs-impl.jar agent-plugins.zip}.each{|file|
        q.add "http://#{gocd_server.host}:#{gocd_server.port}/go/admin/#{file}"
      }
    }.start

    setup.agents.each {|name|
      mkdir_p "#{agents_dir}/#{name}/"
      %w{agent.jar tfs-impl.jar agent-plugins.zip}.each{|file|
        cp_r "#{agents_dir}/#{file}" , "#{agents_dir}/#{name}/"
      }
    }

  end

  task :start => ['agents:stop', 'server:auto_register'] do
    agent_config = Configuration::Agent.new
    puts 'Calling all agents'
    setup.agents.each { |name|
      agent_dir = "#{setup.agents_install_dir}/#{name}"
      mkdir_p "#{agent_dir}/config/"
      cp_r "scripts/autoregister.properties" ,  "#{agent_dir}/config/autoregister.properties"
      log4j_file = "#{agent_dir}/config/agent-log4j.properties"
      cp_r "scripts/agent-log4j.properties" ,  log4j_file
      if agent_config.should_enable_debug_logging
        text = File.read(log4j_file)
        updated_contents = text.gsub(/log4j.logger.com.thoughtworks.go=.*/, "log4j.logger.com.thoughtworks.go=DEBUG")
        .gsub(/log4j.appender.FILE.MaxBackupIndex=.*/, "log4j.appender.FILE.MaxBackupIndex=30")
        File.open(log4j_file, "w") {|file| file.puts updated_contents }
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
      response = RestClient.get("#{gocd_server.url}/api/agents", {accept: "application/vnd.go.cd.v4+json"})
      JSON.parse(response.body)['_embedded']['agents'].each{|agent|
        raise "Agents went missing" if ['Missing', 'LostContact'].include?(agent['agent_state'])
      }
    }
  end
end
