require './lib/configuration'
require 'rest-client'
require './lib/gocd'

include GoCD
include Configuration 

namespace :pipeline do
  setup = SetUp.new
  gocd_server = Server.new

  desc "Create Pipelines"
  task :create => :clean do
    setup.pipelines.each {|pipeline|
      performance_pipeline = Pipeline.new(group: 'performance', name: "#{pipeline}")
      performance_pipeline << GitMaterial.new(url: "#{setup.git_repository_host}/git-repo-#{pipeline}")

      stage = Stage.new(name: 'default')
      job = Job.new(name: 'defaultJob')
      job << Task.new(type: 'exec', attributes: { command: 'ls' })
      stage << job

      performance_pipeline << stage

      begin
        RestClient.post "#{gocd_server.url}/api/admin/pipelines", 
          performance_pipeline.to_json,
          :accept =>  'application/vnd.go.cd.v1+json', 
          :content_type =>  'application/json'

        RestClient.post "#{gocd_server.url}/api/pipelines/#{performance_pipeline.name}/unpause",
          "", :'Confirm'=> true

      rescue => e
        raise "Something went wrong while creating pipeline #{pipeline}. \n Server says:\n #{e.response}"
      end
    }
    p "Created pipeline(s) #{setup.pipelines.join(', ')}"
  end
  
  desc "Clear pipelines"
  task :clean do
    setup.pipelines.each { |pipeline|
      begin
      RestClient.delete "#{gocd_server.url}/api/admin/pipelines/#{pipeline}", 
        :accept =>  'application/vnd.go.cd.v1+json'
      rescue RestClient::ResourceNotFound
      end
    }
  end
end
