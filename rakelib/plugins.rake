require 'rest-client'
require 'json'
require './lib/gocd'
require './lib/downloader'
require './lib/configuration'
require './lib/plugins'
require './lib/looper'
require 'parallel'

namespace :plugins do
  setup = Configuration::SetUp.new
  gocd_server = Configuration::Server.new
  gocd_client = GoCD::Client.new gocd_server.url


  task :setup_analytics_plugin do

    if setup.include_analytics_plugin?
      analytics = Plugins::Elastic_agent.new('resources/analytics_plugin_settings.json')
      analytics.create_plugin_settings_with_actual_values({ 'host' => setup.pg_db_host.to_s,
                                                      'license' => setup.analytics_license_key,
                                                      'password' => setup.pg_db_password}, gocd_client)
    end

  end

  task :setup_file_based_auth do

    if gocd_server.auth == 'Y'
      gocd_client.create_file_based_auth_config('resources/auth_configuration.json')
    end

  end

end
