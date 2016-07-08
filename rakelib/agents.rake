require './lib/gocd'
require './lib/downloader'
require './lib/configuration'

namespace :agent do
  setup = Configuration::SetUp.new

  task :prepare do
    v, b = setup.go_version

    mkdir_p('go-agents')

    Downloader.new('go-agents') {|q|
      q.add "https://download.go.cd/experimental/binaries/#{v}-#{b}/generic/go-agent-#{v}-#{b}.zip"
    }.start { |f|
      f.extractTo('go-agents')
    }

#    (1..NO_OF_AGENTS).each{|i|
#      cp_r "go-agents/go-agent-#{version}" , "go-agents/agent-#{i}"
#      cp_r "scripts/autoregister.properties" ,  "go-agents/agent-#{i}/config/autoregister.properties"
#      sh("chmod +x go-agents/agent-#{i}/agent.sh; GO_SERVER=#{PERF_SERVER_URL[/http:\/\/(.*?)\:/,1]} DAEMON=Y go-agents/agent-#{i}/agent.sh > /dev/null")
#    }

  end
end

