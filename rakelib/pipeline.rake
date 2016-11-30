require './lib/configuration'
require './lib/material'
require 'rest-client'
require './lib/gocd'

include GoCD
include Configuration

namespace :pipeline do
  @setup = SetUp.new
  gocd_server = Server.new

  desc "Create Pipelines"
  task :create => :clean do
    gocd_client = Client.new(gocd_server.url)

    @setup.pipelines.each {|pipeline|
      performance_pipeline = Pipeline.new(group: 'performance', name: "#{pipeline}") do |p|
        p << get_material(pipeline)
        p <<  Stage.new(name: 'default') do |s|
          s << Job.new(name: 'defaultJob') do |j|
            j << ExecTask.new(command: 'ls')
          end
        end
      end

      begin
        gocd_client.create_pipeline(performance_pipeline.to_json)
        gocd_client.unpause_pipeline(performance_pipeline.name)
      rescue => e
        raise "Something went wrong while creating pipeline #{pipeline}. \n Server says:\n #{e.response}"
      end
    }
    p "Created pipeline(s) #{@setup.pipelines.join(', ')}"
  end

  desc "Clear pipelines"
  task :clean do
    @setup.pipelines.each { |pipeline|
      begin
      RestClient.delete "#{gocd_server.url}/api/admin/pipelines/#{pipeline}",
        :accept =>  'application/vnd.go.cd.v3+json'
      rescue RestClient::ResourceNotFound
      end
    }
  end

  def get_material(pipeline)
    pc = pipeline.gsub(/[^0-9]/, '').to_i
    git = Material::Git.new
    tfs = Material::Tfs.new
    if pc.between?(git.begin,git.end)
      material = GitMaterial.new(url: "#{@setup.git_repository_host}/git-repo-#{pipeline}")
    end
    if pc.between?(tfs.begin,tfs.end)
      material = TfsMaterial.new(url: "#{@setup.tfs_url}/defaultcollection", username: @setup.tfs_user, password: @setup.tfs_pwd, project_path: "$/go-perf-#{pc-git.end}")
    end
    material
  end
end
