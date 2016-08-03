require './lib/gocd'
require './lib/downloader'
require './lib/configuration'

namespace :agents do
  setup = Configuration::SetUp.new
  gocd_server = Configuration::Server.new

  task :prepare => 'agents:stop' do
    v, b = setup.go_version

    rm_rf 'go-agents'
    mkdir_p 'go-agents' 

    Downloader.new('go-agents') {|q|
      q.add "https://download.go.cd/experimental/binaries/#{v}-#{b}/generic/go-agent-#{v}-#{b}.zip"
    }.start { |f|
      f.extract_to('go-agents')
    }

    setup.agents.each {|name|
      cp_r "go-agents/go-agent-#{v}" , "go-agents/#{name}"
    }

  end

  task :start => ['agents:stop', 'server:auto_register'] do
    puts 'Calling all agents'
    setup.agents.each { |name|
      agent_dir = "go-agents/#{name}"
      cp_r "scripts/autoregister.properties" ,  "go-agents/#{name}/config/autoregister.properties"
      sh %{chmod +x #{agent_dir}/agent.sh}, verbose:false
      sh %{GO_SERVER=#{gocd_server.host} #{agent_dir}/agent.sh > #{agent_dir}/#{name}.log 2>&1 & }, verbose:false
    }
    puts 'All agents running'
  end

  task :stop do
    sh %{ pkill -f go-agents || true }, verbose:false
    puts 'Stopped all agents'
  end
end

