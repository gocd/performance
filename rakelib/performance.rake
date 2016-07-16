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

  namespace :git do
    task :update => 'git:prepare' do
      duration = setup.git_commit_duration

      Looper::run(duration) {
        setup.git_repos.each do |repo|
          verbose false do
            cd repo do
              time = Time.now
              File.write("file", time.to_f)
              sh("git add .;git commit -m 'This is commit at #{time.rfc2822}' --author 'foo <foo@bar.com>'")
            end
          end
        end
      }
    end
  end
end
