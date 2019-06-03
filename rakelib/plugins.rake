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

  task :configure_k8_cluster_profile do

    secret_name=`kubectl --namespace=#{setup.k8s_namespace} get serviceaccount #{setup.k8_service_account} -o jsonpath="{.secrets[0].name}"`
    secret_token=`kubectl --namespace=#{setup.k8s_namespace} get secret #{secret_name} -o jsonpath="{.data['token']}" | base64 --decode`
    k8_cluster_url=`kubectl config view --minify | grep server | cut -f 2- -d ":" | tr -d " "`
    k8_cluster_ca_cert=`kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}'`

    cluster_profile = Plugins::Elastic_agent.new('resources/k8_cluster_profile.json')
    cluster_profile.create_cluster_profile_with_actual_values({'go_server_url' => setup.go_k8_service_url,
                                                            'auto_register_timeout' => setup.k8_auto_register_timeout,
                                                            'pending_pods_count' => setup.k8_pending_pods_count,
                                                            'kubernetes_cluster_url' => k8_cluster_url ,
                                                            'security_token' => secret_token,
                                                            'namespace' => setup.k8s_namespace,
                                                            'kubernetes_cluster_ca_cert' => k8_cluster_ca_cert
                                                          },gocd_client)
  end


  task :configure_k8_elastic_profile do

    elastic_profile =  Plugins::Elastic_agent.new('resources/k8_elastic_profile.json')
    elastic_profile.create_elastic_profile_with_actual_values({'Image' => setup.gocd_agent_image},gocd_client)
  
  end

end
