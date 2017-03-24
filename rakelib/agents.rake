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
      q.add "#{setup.download_url}/binaries/#{v}-#{b}/generic/go-agent-#{v}-#{b}.zip"
    }.start { |f|
      f.extract_to(agents_dir)
    }

    setup.agents.each {|name|
      cp_r "#{agents_dir}/go-agent-#{v}/." , "#{agents_dir}/#{name}"
    }

  end

  task :start => ['agents:stop', 'server:auto_register'] do
    puts 'Calling all agents'
    setup.agents.each { |name|
      agent_dir = "#{setup.agents_install_dir}/#{name}"
      cp_r "scripts/autoregister.properties" ,  "#{agent_dir}/config/autoregister.properties"
      sh %{chmod +x #{agent_dir}/agent.sh}, verbose:false
      sh %{GO_SERVER=#{gocd_server.host} #{agent_dir}/agent.sh > #{agent_dir}/#{name}.log 2>&1 & }, verbose:false
      sleep 20
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
end
