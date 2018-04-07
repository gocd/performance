require './lib/configuration'
require './lib/gocd'
require './lib/looper'
require 'rest-client'
require 'bundler'
require 'process_builder'
require 'bcrypt'

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

    if setup.include_addons?
      puts "Copying the addons"
      mkdir_p "#{server_dir}/go-server-#{v}/addons/"
      mkdir_p "#{server_dir}/go-server-#{v}/config/"
      sh "curl -L -o #{server_dir}/go-server-#{v}/addons/postgres-addon.jar --fail -H 'Accept: binary/octet-stream' --user '#{ENV['EXTENSIONS_USER']}:#{ENV['EXTENSIONS_PASSWORD']}'  #{ENV['PG_ADDON_DOWNLOAD_URL']}"
      open("#{server_dir}/go-server-#{v}/config/postgresqldb.properties", 'w') do |f|
        f.puts("db.host=#{setup.pg_db_host}")
        f.puts('db.port=5432')
        f.puts('db.name=cruise')
        f.puts('db.user=go')
        f.puts('db.password=go')
      end
    end

    if setup.include_ecs_elastic_agents?
      mkdir_p "#{server_dir}/go-server-#{v}/plugins/external/"
      sh "curl -L -o #{server_dir}/go-server-#{v}/plugins/external/ecs-elastic-agents-plugin.jar --fail -H 'Accept: binary/octet-stream' --user '#{ENV['EXTENSIONS_USER']}:#{ENV['EXTENSIONS_PASSWORD']}'  #{ENV['EA_PLUGIN_DOWNLOAD_URL']}"
    end

    if setup.include_k8s_elastic_agents?
      mkdir_p "#{server_dir}/go-server-#{v}/plugins/external/"
      sh "curl -L -o #{server_dir}/go-server-#{v}/plugins/external/k8s-elastic-agents-plugin.jar --fail  #{ENV['K8S_EA_PLUGIN_DOWNLOAD_URL']}"
    end
  end

  task :start => 'server:stop' do
    v, b = setup.go_version

    server_dir = "#{setup.server_install_dir}/go-server-#{v}"
    %w(logs libs config).each{|dir| mkdir_p "#{server_dir}/#{dir}/"}
    #cp_r "scripts/logback-gelf-1.0.4.jar", "#{server_dir}/libs/"
    #cp_r "scripts/logback.xml" ,  "#{server_dir}/config/"

    Bundler.with_clean_env do
      ProcessBuilder.build('sh', 'server.sh') {|p|
        p.environment = gocd_server.environment
        puts 'Environment variables'
        p.environment.each {|key,value|
          puts "#{key}=#{value}"
        }
        p.directory = server_dir
        p.redirection[:err] = "#{server_dir}/logs/go-server.startup.out.log"
        p.redirection[:out] = "#{server_dir}/logs/go-server.startup.out.log"
      }.spawn
    end

    puts 'Waiting for server start up'
    server_is_running = false
    Looper.run(interval:10, times: 9) {
      begin
        gocd_client.about_page
        server_is_running = true
      rescue
      end
    }

    raise "Couldn't start GoCD server at #{v}-#{b} at #{server_dir}" unless server_is_running
    puts 'The servers up and running'

  end

  task :setup_auth do
    if !gocd_client.auth_enabled?
      gocd_client.set_ldap_auth_config(setup.ldap_server_ip)
      File.open("#{setup.server_install_dir}/password.properties", 'w') { |file| file.write("file_based_user:#{BCrypt::Password.create(ENV['FILE_BASED_USER_PWD'])}") }
      gocd_client.set_file_based_auth_config("#{setup.server_install_dir}/password.properties")
    else
      p "Auth config already setup on the server, skipping."
    end
  end

  task :enable_new_dashboard do
    gocd_client.enable_toggle('quicker_dashboard_key')
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
