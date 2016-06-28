require './lib/configuration'
require 'rest-client'
require './lib/gocd'

include GoCD
namespace :pipeline do
  configuration = Configuration.new

  desc "Create Pipelines"
  task :create => :clean do
    configuration.pipelines.each {|pipeline|
      performance_pipeline = Pipeline.new(group: 'performance', name: "#{pipeline}")
      performance_pipeline << GitMaterial.new(url: "git://#{configuration.git_repository_server}/git-repo-#{pipeline}")

      stage = Stage.new(name: 'default')
      job = Job.new(name: 'defaultJob')
      job << Task.new(type: 'exec', attributes: { command: 'ls' })
      stage << job

      performance_pipeline << stage

      begin
        RestClient.post "#{configuration.gocd_host}/api/admin/pipelines", 
          performance_pipeline.to_json,
          :accept =>  'application/vnd.go.cd.v1+json', 
          :content_type =>  'application/json'

        RestClient.post "#{configuration.gocd_host}/api/pipelines/#{performance_pipeline.name}/unpause",
          "", :'Confirm'=> true

      rescue => e
        raise "Something went wrong while creating pipeline #{pipeline}. \n Server says:\n #{e.response}"
      end
    }
    p "Created pipeline(s) #{configuration.pipelines.join(', ')} at #{configuration.gocd_host}/pipelines"
  end
  
  desc "Clear pipelines"
  task :clean do
    configuration.pipelines.each { |pipeline|
      begin
      RestClient.delete "#{configuration.gocd_host}/api/admin/pipelines/#{pipeline}", 
        :accept =>  'application/vnd.go.cd.v1+json'
      rescue RestClient::ResourceNotFound
      end
    }
  end
end
