require './lib/configuration'
require './lib/gocd'

namespace :server do
  gocd_server = Configuration::Server.new
  gocd_client = GoCD::Client.new gocd_server.url
  setup = Configuration::SetUp.new

  task :prepare do
    v, b = setup.go_version

    mkdir_p('go-server')

    Downloader.new('go-server') {|q|
      q.add "https://download.go.cd/experimental/binaries/#{v}-#{b}/generic/go-server-#{v}-#{b}.zip"
    }.start { |f|
      f.extractTo('go-server')
    }

  end

  task :start do
    v, b = setup.go_version

    server_dir = "go-server/go-server-#{v}" 

    sh %{ chmod +x #{server_dir}/server.sh }, verbose:false
    sh %{ #{server_dir}/server.sh > #{server_dir}/server.out.log 2>&1 & }, verbose: false

    puts 'Waiting for server to come up'
    sh("wget #{get_url}/about --waitretry=90 --retry-connrefused --quiet -O /dev/null")
    puts 'The servers up and running'
  end

  task :stop do
    sh %{ pkill -f go-server }, verbose:false
    puts 'Stopped server'
  end

  task :auto_register do
    gocd_client.set_auto_register_key 'perf-auto-register-key'
  end

end
