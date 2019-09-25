require 'rest-client'
require 'json'
require './lib/gocd'
require './lib/downloader'
require './lib/configuration'
require './lib/looper'
require 'parallel'
require 'nokogiri'

namespace :agents do
  setup = Configuration::SetUp.new
  gocd_server = Configuration::Server.new
  gocd_client = GoCD::Client.new "#{gocd_server.secure_url}/go"

  task prepare: 'agents:stop' do
    v, b = setup.go_version

    agents_dir = setup.agents_install_dir
    Parallel.each(setup.agents, in_processes: 5) do |name|
      rm_rf "#{agents_dir}/#{name}/"
    end
    mkdir_p agents_dir

    cd agents_dir do
      sh %(wget --no-check-certificate https://#{gocd_server.host}:#{gocd_server.secure_port}/go/admin/agent.jar), verbose: false
      %w[tfs-impl.jar agent-plugins.zip].each do |file|
        sh %(wget --no-check-certificate https://#{gocd_server.host}:#{gocd_server.secure_port}/go/admin/#{file}), verbose: false
      end
    end

    Parallel.each(setup.agents, in_processes: 5) do |name|
      mkdir_p "#{agents_dir}/#{name}/libs"
      %w[agent.jar tfs-impl.jar agent-plugins.zip].each do |file|
        cp_r "#{agents_dir}/#{file}", "#{agents_dir}/#{name}/"
      end
      # cp "scripts/logback-gelf-1.0.4.jar", "#{agents_dir}/#{name}/libs/"
    end
  end

  task start: ['agents:stop'] do
    p "setting up Java 11"
    sh 'curl https://download.java.net/openjdk/jdk11/ri/openjdk-11+28_linux-x64_bin.tar.gz -o /home/openjdk-11+28_linux-x64_bin.tar.gz'
    sh 'tar -xvf /home/openjdk-11+28_linux-x64_bin.tar.gz -C /home/'
    sh 'unlink /usr/bin/java'
    sh 'ln -s -f /home/jdk-11/bin/java /usr/bin/java'
    agent_config = Configuration::Agent.new
    puts 'Calling all agents'
    Parallel.each(setup.agents, in_processes: 5) do |name|
      agent_dir = "#{setup.agents_install_dir}/#{name}"
      mkdir_p "#{agent_dir}/config/"
      cp_r 'scripts/autoregister.properties', "#{agent_dir}/config/autoregister.properties"
      cp_r 'scripts/with-java.sh', "#{agent_dir}/with-java.sh"
      chmod_R 0755, "#{agent_dir}/"
      # logback_file = "#{agent_dir}/config/agent-logback.xml"
      # cp_r "scripts/agent-logback.xml" ,  logback_file

      cd agent_dir do
        sh %(java #{agent_config.startup_args} -jar agent.jar -serverUrl https://#{gocd_server.host}:#{gocd_server.secure_port}/go > #{name}.log 2>&1 & ), verbose: false
        sleep 20
      end
    end
    Looper.run(interval: 10, times: 120) do
      break if gocd_client.get_agents_count >= setup.agents.length
    end
    if gocd_client.get_agents_count < setup.agents.length
      raise "All agents are not up as expected. Expected agents #{setup.agents.length} and actual is #{gocd_client.get_agents_count}"
    end
    puts 'All agents running'
  end

  task :stop do
    verbose false do
      sh %( pkill -f #{gocd_server.host} ) do |ok, _res|
        puts 'Stopped all agents' if ok
      end
    end
  end

  task :monitor do
    Looper.run(interval: 300, times: setup.load_test_duration.to_i / 300) do
      response = RestClient.get("#{gocd_server.url}/api/agents", accept: 'application/vnd.go.cd.v4+json', Authorization: "Basic #{Base64.encode64(['file_based_user', ENV['FILE_BASED_USER_PWD']].join(':'))}")
      JSON.parse(response.body)['_embedded']['agents'].each do |agent|
        raise 'Agents went missing' if %w[Missing LostContact].include?(agent['agent_state'])
      end
    end
  end
end
