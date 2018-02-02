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

end
