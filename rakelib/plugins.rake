require 'rest-client'
require 'json'
require './lib/gocd'
require './lib/downloader'
require './lib/configuration'
require './lib/looper'
require 'parallel'

namespace :plugins do
  setup = Configuration::SetUp.new
  gocd_server = Configuration::Server.new
  gocd_client = GoCD::Client.new gocd_server.url

  task :setup_ecs_ea do
    settings = JSON.parse(File.read("resources/ecs_plugin_settings.json"))
    properties = settings['configuration'].each{|key_value|
      key_value['value'] = "#{gocd_server.secure_url}/go" if key_value['key'] == "GoServerUrl"
      key_value['value'] = setup.aws_secret if key_value['key'] == "AWSSecretAccessKey"
      key_value['value'] = setup.aws_access_key if key_value['key'] == "AWSAccessKeyId"
      key_value['value'] = setup.aws_iam_profile if key_value['key'] == "EC2IAMInstanceProfile"
    }
    settings.each_with_object({}) { |(key, value), hash| hash[key] = properties if key == 'configuration'}
    gocd_client.create_ecs_plugin_settings(settings.to_json)
  end

  task :setup_ecs_ea_profile do
    gocd_client.create_ecs_profile(JSON.parse(File.read("resources/ecs_plugin_profile.json")).to_json)
  end

end
