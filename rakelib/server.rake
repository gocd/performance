require './lib/configuration'
require './lib/gocd'
require './lib/looper'
require 'rest-client'
require 'bundler'
require 'process_builder'
require 'bcrypt'
require 'yaml'
require 'json'

namespace :server do
  @gocd_server = Configuration::Server.new
  @gocd_client = GoCD::Client.new @gocd_server.url
  @setup = Configuration::SetUp.new

  task prepare: 'server:stop' do
    v, b = @setup.go_version

    server_dir = @setup.server_install_dir
    mkdir_p server_dir unless Dir.exist? server_dir

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
    %w[artifacts config db].each do |fldr|
      mv "#{server_dir}/go-server-20.1.0/#{fldr}", "#{server_dir}/go-server-#{v}/", force: true
    end

    if @setup.include_addons?
      puts 'Copying the addons'
      mkdir_p "#{server_dir}/go-server-#{v}/addons/"
      mkdir_p "#{server_dir}/go-server-#{v}/config/" unless Dir.exist? "#{server_dir}/go-server-#{v}/config/"
      sh "curl -L -o #{server_dir}/go-server-#{v}/addons/postgres-addon.jar --fail -H 'Accept: binary/octet-stream' --user '#{ENV['EXTENSIONS_USER']}:#{ENV['EXTENSIONS_PASSWORD']}'  #{ENV['PG_ADDON_DOWNLOAD_URL']}"
      unless File.exist? "#{server_dir}/go-server-#{v}/config/postgresqldb.properties"
        open("#{server_dir}/go-server-#{v}/config/postgresqldb.properties", 'w') do |f|
          f.puts("db.host=#{@setup.pg_db_host}")
          f.puts('db.port=5432')
          f.puts('db.name=cruise')
          f.puts('db.user=postgres')
          f.puts("db.password=#{@setup.pg_db_password}")
        end
      end
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

    File.open("#{@setup.server_install_dir}/password.properties", 'w') { |file| file.write("file_based_user:#{BCrypt::Password.create(ENV['FILE_BASED_USER_PWD'])}") }
  end

  task start: ['server:stop'] do
    v, b = @setup.go_version

    server_dir = "#{@setup.server_install_dir}/go-server-#{v}"
    %w[logs libs].each { |dir| mkdir_p "#{server_dir}/#{dir}/" }
    cp_r 'scripts/with-java.sh', "#{server_dir}/with-java.sh"
    chmod_R 0o755, "#{server_dir}/bin"
    chmod_R 0o755, "#{server_dir}/with-java.sh"

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
    Looper.time_out(interval: 10, times: 30) do
      begin
        res = @gocd_client.about_page
        if res.code == 200
          server_is_running = true
          break
        end
      rescue StandardError => e
        p "Server ping request failed. #{e.message}"
      end
    end

    raise "Couldn't start GoCD server" unless server_is_running

    puts 'The server is up and running'
  end

  task :stop do
    verbose false do
      sh %( pkill -f go-server ) do |ok, _res|
        puts 'Stopped server' if ok
      end
    end
  end

  task :setup_secrets do
    server_dir = @setup.server_install_dir
    file_path = setup_secrets_config_file(server_dir)
    setup_secrets_config(file_path)
  end

  def setup_secrets_config_file(server_dir)
    v, b = @setup.go_version
    mkdir_p "#{server_dir}/secrets"

    sh %(java -jar #{server_dir}/go-server-#{v}/plugins/bundled/gocd-file-based-secrets-plugin.jar init -f #{server_dir}/secrets/secret.db)
    (1..100).each do |counter|
      sh %(java -jar #{server_dir}/go-server-#{v}/plugins/bundled/gocd-file-based-secrets-plugin.jar add -f #{server_dir}/secrets/secret.db -n secret_var_#{counter} -v value)
    end
    "#{server_dir}/secrets/secret.db"
  end

  task :setup_auth do
    File.open("#{@setup.server_install_dir}/password.properties", 'w') { |file| file.write("file_based_user:#{BCrypt::Password.create(ENV['FILE_BASED_USER_PWD'])}") }
    if !@gocd_client.auth_enabled?
      # @gocd_client.set_ldap_auth_config(@setup.ldap_server_ip)
      @gocd_client.setup_file_based_auth_config("#{@setup.server_install_dir}/password.properties")
    else
      p 'Auth config already setup on the server, skipping.'
    end
  end

  task :setup_config_repo do
    @gocd_client.setup_config_repo(@setup.git_repository_host)
  end

  task :create_environment do
    @gocd_client.create_environment('performance')
  end

  task :auto_register do
    @gocd_client.auto_register_key 'perf-auto-register-key'
  end

  def setup_secrets_config(secret_file_path)
    secret_config = %({
                      "id": "perf_secret",
                      "plugin_id": "cd.go.secrets.file-based-plugin",
                      "description": "",
                      "properties": [
                          {
                              "key": "SecretsFilePath",
                              "value": "#{secret_file_path}"
                          }
                      ],
                      "rules": [
                          {
                              "directive": "allow",
                              "action": "refer",
                              "type": "*",
                              "resource": "*"
                          }
                      ]
                    })
    @gocd_client.create_secret_config(secret_config)
  end



end
