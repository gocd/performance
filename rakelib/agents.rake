require './lib/gocd'
require './lib/downloader'
require './lib/configuration'

namespace :agents do
  setup = Configuration::SetUp.new
  gocd_server = Configuration::Server.new

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
      cp_r "#{agents_dir}/go-agent-#{v}" , "#{agents_dir}/#{name}"
    }

  end

  task :start => ['agents:stop', 'server:auto_register'] do
    puts 'Calling all agents'
    setup.agents.each { |name|
      agent_dir = "#{setup.agents_install_dir}/#{name}"
      cp_r "scripts/autoregister.properties" ,  "#{agent_dir}/config/autoregister.properties"
      sh %{chmod +x #{agent_dir}/agent.sh}, verbose:false
      sh %{GO_SERVER=#{gocd_server.host} #{agent_dir}/agent.sh > #{agent_dir}/#{name}.log 2>&1 & }, verbose:false
    }
    puts 'All agents running'
  end

  task :stop do
    verbose false do
      sh %{ pkill -f go-agents } do |ok, res|
        puts 'Stopped all agents' if ok
      end
    end
  end
end
