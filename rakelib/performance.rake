require './lib/gocd'
require './lib/configuration'
require './lib/looper'

namespace :performance do
  go_server = Configuration::Server.new
  setup = Configuration::SetUp.new 

  gocd_client = GoCD::Client.new go_server.url

  namespace :config do
    task :update do
      duration = setup.config_save_duration
      puts "Saving config by setting the job timeout in a loop #{duration}"
      Looper::run(duration) { 
        timeout = 60 + rand(9)

        puts "Setting job timeout to #{timeout}"
        gocd_client.set_job_timeout timeout
      } 
    end
  end
end
