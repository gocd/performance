require './lib/configuration'
require './lib/gocd'

namespace :server do
  gocd_server = Configuration::Server.new
  gocd_client = GoCD::Client.new gocd_server.url
  task :prepare => :auto_register do
    
  end
  task :auto_register do
    gocd_client.set_auto_register_key 'perf-auto-register-key'
  end
end
