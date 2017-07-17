##########################################################################
# Copyright 2017 ThoughtWorks, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##########################################################################

require './lib/gocd/pipeline.rb'
require 'assert_json'

include AssertJson
include GoCD

describe Pipeline do

  it 'sets default values on a new instance' do
    expect(Pipeline.new().data).to eq({
        group: nil,
        enable_pipeline_locking: false,
        environment_variables: [],
        label_template: '${COUNT}',
        materials: [],
        params: [],
        stages: [],
        template: nil,
        timer: nil,
        tracking_tool: nil
      })
  end

  it 'sets the group and name' do
    pipeline = Pipeline.new(group: 'perfgroup', name: 'name')
    assert_json(pipeline.to_json) do
      has :group, 'perfgroup'
      has :pipeline do
        has :name, 'name'
      end
    end
  end

  it 'adds material' do
    pipeline = Pipeline.new(name: 'name')
    pipeline << Material.new(type: 'git', attributes: { url: 'git://localhost/git-repo-1' })

    expect(pipeline.materials.first).to eq({type: 'git', attributes: { url: 'git://localhost/git-repo-1' }})
  end

  it 'adds environment variables' do
    pipeline = Pipeline.new(name: 'pipeline_with_environment_variables')
    pipeline << EnvironmentVariable.new(name:'variable', value:'value')
    expect(pipeline.environment_variables.first).to eq({ name:'variable', value:'value', secure:false})
  end

  it 'adds parameter' do
    pipeline = Pipeline.new(name: 'pipeline_with_paramters')
    pipeline << Parameter.new(name:'parameter', value:'value')
    expect(pipeline.params.first).to eq({name:'parameter', value:'value'})
  end

  it 'adds stage' do
    pipeline = Pipeline.new(name: 'pipeline_with_stage' )
    pipeline << Stage.new(name: "stage_name" )

    assert_json(pipeline.to_json) do
      has :pipeline do
        has :stages do
          item 0 do
            has :name, 'stage_name'
          end
        end
      end
    end
  end

  describe 'Block initialization' do
    before :each do
      @pipeline = Pipeline.new(name: 'pipeline_with_block_init') do |p|
        p << Stage.new(name: 'stage_name') do |s|
          s << Job.new(name: 'job') do |j|
            j << Task.new(type: 'exec', attributes: { command: 'ls' })
          end
        end
      end
    end

    it 'sets the pipeline name' do
      expect(@pipeline.name).to eq('pipeline_with_block_init')
    end

    it 'adds the stage' do
      expect(@pipeline.stages.first[:name]).to eq('stage_name')
    end

    it 'adds the job' do
      expect(@pipeline.stages.first[:jobs].first[:name]).to eq('job')
    end

    it 'adds the task' do
      expect(@pipeline.stages.first[:jobs].first[:tasks].first[:type]).to eq('exec')
    end
  end
end

describe Stage do
  it 'sets default values' do
    expect(Stage.new(name: 'defaultStage').data).to eq({
        name: "defaultStage",
        approval: {
          type: "success",
          authorization: {
            roles: [],
            users: []
          }
        },
        clean_working_directory: false,
        environment_variables: [],
        fetch_materials: true,
        jobs: [],
        never_cleanup_artifacts: false
      })
  end

  it 'adds a job' do
    stage = Stage.new(name: 'stage_with_job')
    stage << Job.new(name:'job')
    expect(stage.jobs.first[:name]).to eq('job')
  end
end

describe Job do
  it 'sets default values' do
    expect(Job.new(name: 'defaultJob').data).to eq({
        name: "defaultJob",
        artifacts: [],
        environment_variables: [],
        properties: nil,
        resources:[],
        elastic_profile_id:nil,
        run_count_instance: nil,
        tabs: [],
        tasks: [],
        timeout:0
        })
  end

  it 'adds task' do
    job = Job.new(name: 'job_with_task')
    job << Task.new(type: 'exec', attributes: { command: 'ls' });
    expect(job.tasks.first).to eq({type: 'exec', attributes: { command: 'ls' }})
  end
end

describe GitMaterial do
  it 'sets default values' do
    expect(GitMaterial.new(url: 'giturl').data).to eq({
      type: 'git',
      attributes: {
        auto_update: true,
        destination: '',
        filter: nil,
        name: nil,
        url: "giturl",
        shallow_clone: true
      }
    })
  end
end

describe ExecTask do
  it 'sets the default values' do
    expect(ExecTask.new(command: 'ls').data).to eq({
      type: 'exec',
      attributes: {
        command: 'ls'
      }
    })
  end
end
