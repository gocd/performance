require './lib/configuration'
require './lib/gocd'
require './lib/looper'
require 'rest-client'
require 'bundler'
require 'process_builder'
require 'bcrypt'
require 'yaml'

namespace :server do
  @gocd_server = Configuration::Server.new
  @gocd_client = GoCD::Client.new @gocd_server.url
  @setup = Configuration::SetUp.new

  task prepare: 'server:stop' do
    v, b = @setup.go_version

    server_dir = @setup.server_install_dir

    Downloader.new(server_dir.to_s) do |q|
      q.add "#{@setup.download_url}/binaries/#{v}-#{b}/generic/go-server-#{v}-#{b}.zip"
    end.start do |f|
      f.extract_to(server_dir.to_s)
    end

    if @setup.include_plugins?
      puts 'Copying the plugins'
      mkdir_p "#{server_dir}/go-server-#{v}/plugins/external/"
      cp @setup.plugin_src_dir.to_s, "#{server_dir}/go-server-#{v}/plugins/external/"
    end

    # Copy all the files from previous run of performance
    %w[config artifacts db secrets].each do |fldr|
      cp_r "/var/go/server/go-server/19.7.0/#{fldr}", "#{server_dir}/go-server-#{v}/"
    end

    if @setup.include_addons?
      puts 'Copying the addons'
      mkdir_p "#{server_dir}/go-server-#{v}/addons/"
      sh "curl -L -o #{server_dir}/go-server-#{v}/addons/postgres-addon.jar --fail -H 'Accept: binary/octet-stream' --user '#{ENV['EXTENSIONS_USER']}:#{ENV['EXTENSIONS_PASSWORD']}'  #{ENV['PG_ADDON_DOWNLOAD_URL']}"
    end

    mkdir_p "#{server_dir}/go-server-#{v}/plugins/external/"

    if @setup.include_ecs_elastic_agents?
      sh "curl -L -o #{server_dir}/go-server-#{v}/plugins/external/ecs-elastic-agents-plugin.jar --fail -H 'Accept: binary/octet-stream' --user '#{ENV['EXTENSIONS_USER']}:#{ENV['EXTENSIONS_PASSWORD']}'  #{ENV['EA_PLUGIN_DOWNLOAD_URL']}"
    end

    if @setup.include_k8s_elastic_agents?
      sh "curl -L -o #{server_dir}/go-server-#{v}/plugins/external/k8s-elastic-agents-plugin.jar --fail  #{ENV['K8S_EA_PLUGIN_DOWNLOAD_URL']}"
    end

    if @setup.include_analytics_plugin?
      sh "curl -L -o #{server_dir}/go-server-#{v}/plugins/external/analytics-plugin.jar --fail -H 'Accept: binary/octet-stream' --user '#{ENV['EXTENSIONS_USER']}:#{ENV['EXTENSIONS_PASSWORD']}' #{ENV['ANALYTICS_PLUGIN_DOWNLOAD_URL']}"
    end

    if @setup.include_azure_elastic_agents?
      sh "curl -L -o #{server_dir}/go-server-#{v}/plugins/external/azure-elastic-agents-plugin.jar --fail -H 'Accept: binary/octet-stream' --user '#{ENV['EXTENSIONS_USER']}:#{ENV['EXTENSIONS_PASSWORD']}' #{ENV['AZURE_EA_PLUGIN_DOWNLOAD_URL']}"
    end
  end

  task start: ['server:stop', 'server:setup_newrelic_agent'] do
    v, b = @setup.go_version

    server_dir = "#{@setup.server_install_dir}/go-server-#{v}"
    %w[logs libs].each { |dir| mkdir_p "#{server_dir}/#{dir}/" }
    cp_r 'scripts/with-java.sh', "#{server_dir}/with-java.sh"
    chmod_R 0o755, "#{server_dir}/"

    File.open("#{server_dir}/wrapper-config/wrapper-properties.conf", 'w') do |file|
      @gocd_server.environment.split(',').each_with_index do |item, index|
        file.puts("wrapper.java.additional.#{index.to_i + 100}=#{item}")
      end
    end

    Bundler.with_clean_env do
      ProcessBuilder.build('./with-java.sh', 'bin/go-server', 'start') do |p|
        p.directory = server_dir
        p.redirection[:err] = "#{server_dir}/logs/go-server.startup.out.log"
        p.redirection[:out] = "#{server_dir}/logs/go-server.startup.out.log"
      end.spawn
    end

    puts 'Waiting for server start up'
    server_is_running = false
    Looper.run(interval: 10, times: 18) do
      begin
        @gocd_client.about_page
        server_is_running = true
      rescue StandardError
      end
    end

    raise "Couldn't start GoCD server at #{v}-#{b} at #{server_dir}" unless server_is_running

    revision = @setup.include_addons? ? "#{v}-#{b}-PG" : "#{v}-#{b}-H2"
    sh %(java -jar /var/go/newrelic/newrelic-agent.jar deployment --appname='GoCD Perf Server' --revision="#{revision}")
    puts 'The server is up and running'
  end

  task :stop do
    verbose false do
      sh %( pkill -f go-server ) do |ok, _res|
        puts 'Stopped server' if ok
      end
    end
  end

  task :setup_newrelic_agent do
    rm_rf '/var/go/newrelic'
    mkdir_p '/var/go/newrelic'
    sh %(wget http://central.maven.org/maven2/com/newrelic/agent/java/newrelic-agent/4.12.0/newrelic-agent-4.12.0.jar -O /var/go/newrelic/newrelic-agent.jar)
    sh %(wget http://central.maven.org/maven2/com/newrelic/agent/java/newrelic-api/4.12.0/newrelic-api-4.12.0.jar -O /var/go/newrelic/newrelic-api.jar)
    newrelic_config = File.read('resources/newrelic.yml')
    newrelic_config.gsub!(/<%= license_key %>/, @setup.newrelic_license_key)
    File.open('/var/go/newrelic/newrelic.yml', 'w') do |f|
      f.write newrelic_config
    end
  end

end
