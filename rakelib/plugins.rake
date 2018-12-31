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

  task :setup_ecs_ea do
    if setup.include_ecs_elastic_agents?
      ecs = Plugins::Elastic_agent.new('resources/ecs_plugin_settings.json')
      ecs.create_plugin_settings_with_actual_values({ 'GoServerUrl' => "#{gocd_server.secure_url}/go",
                                                      'AWSSecretAccessKey' => setup.aws_secret,
                                                      'AWSAccessKeyId' => setup.aws_access_key,
                                                      'IamInstanceProfile' => setup.aws_iam_profile }, gocd_client)
    end
  end

  task :setup_ecs_ea_profile do
    gocd_client.create_profile(JSON.parse(File.read('resources/ecs_plugin_profile.json')).to_json) if setup.include_ecs_elastic_agents?
  end

  task :setup_k8s_ea do
    if setup.include_k8s_elastic_agents?
      k8s_auth = all_k8s_info
      k8s = Plugins::Elastic_agent.new('resources/k8s_plugin_settings.json')
      k8s.create_plugin_settings_with_actual_values({ 'GoServerUrl' => "#{gocd_server.secure_url}/go",
                                                      'security_token' => k8s_auth['token'],
                                                      'namespace' => setup.k8s_namespace,
                                                      'kubernetes_cluster_url' => k8s_auth['cluster_url'],
                                                      'kubernetes_cluster_ca_cert' => k8s_auth['cacrt'] }, gocd_client)
    end
  end

  task :setup_k8s_ea_profile do
    gocd_client.create_profile(JSON.parse(File.read('resources/k8s_plugin_profile.json')).to_json) if setup.include_k8s_elastic_agents?
  end

  task :setup_analytics_plugin do
    if setup.include_analytics_plugin?
      k8s = Plugins::Elastic_agent.new('resources/analytics_plugin_settings.json')
      k8s.create_plugin_settings_with_actual_values({ 'host' => setup.pg_db_host.to_s,
                                                      'license' => setup.analytics_license_key,
                                                      'password' => setup.pg_db_password}, gocd_client)
    end
  end

  def all_k8s_info
    k8s_info = {}
    k8s_info['cluster_url'] = JSON.parse(`kubectl config view  -o json`)['clusters'].select { |cluster| cluster['name'] == "gke_#{ENV['K8S_PROJECT_NAME']}_#{ENV['K8S_REGION']}_#{ENV['K8S_CLUSTER_NAME']}" }[0]['cluster']['server']
    secret = `kubectl  get serviceaccount default -o jsonpath="{.secrets[0].name}"`
    k8s_info['token'] = `kubectl  get secret #{secret} -o jsonpath="{.data['token']}" | base64 --decode`
    k8s_info['cacrt'] = `kubectl get secret #{secret} -o jsonpath="{.data['ca\\.crt']}"  | base64 --decode`
    ["-----BEGIN CERTIFICATE-----\n", "\n-----END CERTIFICATE-----\n"].each { |remove| k8s_info['crt'].slice! remove }
    sh 'Kubectl delete clusterrolebinding clusterRoleBinding || true'
    sh 'kubectl create clusterrolebinding clusterRoleBinding --clusterrole=cluster-admin --serviceaccount=default:default'
    k8s_info
  end

end
