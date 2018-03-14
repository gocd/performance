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
    ecs = Plugins::Elastic_agent.new("resources/ecs_plugin_settings.json")
    ecs.create_plugin_settings_with_actual_values({"GoServerUrl" => "#{gocd_server.secure_url}/go",
                                                   "AWSSecretAccessKey" => setup.aws_secret,
                                                   "AWSAccessKeyId" => setup.aws_access_key,
                                                   "EC2IAMInstanceProfile" => setup.aws_iam_profile},gocd_client)
  end

  task :setup_ecs_ea_profile do
    gocd_client.create_profile(JSON.parse(File.read("resources/ecs_plugin_profile.json")).to_json)
  end

  task :setup_k8s_ea do
    k8s = Plugins::Elastic_agent.new("resources/k8s_plugin_settings.json")
    k8s.create_plugin_settings_with_actual_values({"GoServerUrl" => "#{gocd_server.secure_url}/go",
                                                   "security_token" => setup.k8s_token,
                                                   "namespace" => setup.k8s_namespace,
                                                   "kubernetes_cluster_ca_cert" => setup.k8s_ca_cert},gocd_client)
  end

  task :setup_k8s_ea_profile do
    gocd_client.create_profile(JSON.parse(File.read("resources/k8s_plugin_profile.json")).to_json)
  end

end
