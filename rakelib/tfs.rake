require './lib/configuration.rb'
require 'rest-client'

namespace :tfs do
  setup = Configuration::SetUp.new

# Task to create the respos in Visual Studio Team Services.
# Run it only when needed - when you change the VS team services instance used for perf test
  task :create do
    basic_auth = Base64.encode64([setup.tfs_user, setup.tfs_pwd].join(':'))
    (1..100).each {|i|
      jdata = %Q({
        "name": "go-perf-#{i}",
        "description": "go test project",
        "capabilities": {
          "versioncontrol": {
            "sourceControlType": "tfvc"
          },
          "processTemplate": {
            "templateTypeId": "6b724908-ef14-45cf-84f8-768b5384da45"
          }
        }
      })
      begin
        RestClient::Request.execute(
          method: :POST,
          url: "#{setup.tfs_url}/defaultcollection/_apis/projects?api-version=2.0-preview",
          payload: jdata,
          headers: { "Authorization" => "Basic #{basic_auth}", content_type: :json }
        )
      rescue RestClient::ExceptionWithResponse
      end
    }
  end

  task :prepare => :download do
    cd setup.tee_dir do
      sh "yes | ./tf eula; true"
    end
  end

  task :download do
    if(!Dir.exists?(setup.tee_dir))
      download_dir = setup.tools_dir + "downloads"
      mkdir_p download_dir if !Dir.exists? download_dir

      puts "Downloading and setting up Team Explorer ErveryWhere"
      Downloader.new(download_dir) { |q|
        q.add "https://fmtgocddl01.go.cd/local/TEE-CLC-14.0.3.zip"
      }.start
      sh "unzip #{download_dir}/TEE-CLC-14.0.3.zip -d #{setup.tools_dir}"

    end
  end


end
