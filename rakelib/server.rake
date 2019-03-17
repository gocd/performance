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
  gocd_server = Configuration::Server.new
  gocd_client = GoCD::Client.new gocd_server.url
  setup = Configuration::SetUp.new

  task :check_gocd_server_status do
    server_is_running = false
    Looper.run(interval: 15, times: 35) do
      begin
        puts "Waiting for server start up at #{gocd_server.url}"
        response = gocd_client.about_page
        if (response.code == 200) then
          server_response = gocd_client.get_version
          $version = JSON.parse(server_response.body)['version']
          $build_number = JSON.parse(server_response.body)['build_number']
          server_is_running = true
          break
        end
      rescue StandardError
      end
    end

    raise "Couldn't start GoCD server" unless server_is_running
    

    revision = setup.include_addons? ? "#{$version}-#{$build_number}-PG" : "#{$version}-#{$build_number}-H2"
   sh("curl -L -o 'resources/newrelic-agent.jar' --fail 'http://central.maven.org/maven2/com/newrelic/agent/java/newrelic-agent/4.7.0/newrelic-agent-4.7.0.jar'")
    
  sh %(java -jar resources/newrelic-agent.jar deployment --appname='GoCD Perf Server' --revision="#{revision}")
    puts 'The server is up and running'
  end

  task :setup_auth do
    if !gocd_client.auth_enabled?
      # gocd_client.set_ldap_auth_config(setup.ldap_server_ip)
      File.open("#{setup.server_install_dir}/password.properties", 'w') { |file| file.write("file_based_user:#{BCrypt::Password.create(ENV['FILE_BASED_USER_PWD'])}") }
      gocd_client.set_file_based_auth_config("#{setup.server_install_dir}/password.properties")
    else
      p 'Auth config already setup on the server, skipping.'
    end
  end

  task :setup_config_repo do
    gocd_client.setup_config_repo(setup.git_repository_host)
  end

  task :create_environment do
    gocd_client.create_environment('performance')
  end

  task :enable_new_dashboard do
    gocd_client.enable_toggle('quicker_dashboard_key')
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
    newrelic_config.gsub!(/<%= license_key %>/, setup.newrelic_license_key)
    File.open('/var/go/newrelic/newrelic.yml', 'w') do |f|
      f.write newrelic_config
    end
  end

  task :auto_register do
    gocd_client.auto_register_key 'perf-auto-register-key'
  end

end
