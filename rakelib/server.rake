require './lib/configuration'
require './lib/gocd'
require './lib/looper'
require 'rest-client'
require 'bundler'
require 'process_builder'

namespace :server do
  gocd_server = Configuration::Server.new
  gocd_client = GoCD::Client.new gocd_server.url
  setup = Configuration::SetUp.new

  task :prepare => 'server:stop' do
    v, b = setup.go_version

    server_dir = setup.server_install_dir
    rm_rf "#{server_dir}"
    mkdir_p "#{server_dir}"

    Downloader.new("#{server_dir}") {|q|
      q.add "#{setup.download_url}/binaries/#{v}-#{b}/generic/go-server-#{v}-#{b}.zip"
    }.start { |f|
      f.extract_to("#{server_dir}")
    }

    if setup.include_plugins?
      puts 'Copying the plugins'
      mkdir_p "#{server_dir}/go-server-#{v}/plugins/external/"
      cp "#{setup.plugin_src_dir}", "#{server_dir}/go-server-#{v}/plugins/external/"
    end

  end

  task :start => 'server:stop' do
    v, b = setup.go_version

    server_dir = "#{setup.server_install_dir}/go-server-#{v}"

    Bundler.with_clean_env do
      ProcessBuilder.build('sh', 'server.sh') {|p|
        p.environment = gocd_server.environment
        puts 'Environment variables'
        p.environment.each {|key,value|
          puts "#{key}=#{value}"
        }
        p.directory = server_dir
        p.redirection[:err] = 'go-server.startup.out.log'
        p.redirection[:out] = 'go-server.startup.out.log'
      }.spawn
    end

    puts 'Waiting for server start up'
    server_is_running = false
    Looper.run(interval:10, times: 9) {
      begin
        gocd_client.support_page
        server_is_running = true
      rescue
      end
    }

    raise "Couldn't start GoCD server at #{v}-#{b} at #{server_dir}" unless server_is_running
    puts 'The servers up and running'
  end

  task :stop do
    verbose false do
      sh %{ pkill -f go-server } do |ok, res|
        puts 'Stopped server' if ok
      end
    end
  end

  task :auto_register do
    gocd_client.auto_register_key 'perf-auto-register-key'
  end
end
