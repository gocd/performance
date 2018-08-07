##########################################################################
# Copyright 2018 ThoughtWorks, Inc.
#
# Licensed under the Apache License, Version 2.0 (the License);
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an AS IS BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##########################################################################

require 'json'
require 'json_builder'
require 'deep_merge'

module GoCD

  class ConfigRepoPipeline < Configuration
    def default
      {
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
      }
    end

    def <<(instance)
      super(instance)
      self.stages << instance.data if instance.is_a? ConfigRepoStage
      self.materials << instance.data if instance.is_a? ConfigRepoMaterial
    end

    def to_json
      pipeline = self

      JSONBuilder::Compiler.generate do
        name pipeline.name
        group pipeline.group
        enable_pipeline_locking false
        materials pipeline.materials
        environment_variables pipeline.environment_variables
        stages pipeline.stages
      end
    end

  end

  class ConfigRepoMaterial < Configuration; end
  class ConfigRepoGitMaterial < ConfigRepoMaterial
    def default
      {
        type: 'git',
        auto_update: true,
        destination: '',
        filter: nil,
        name: nil,
        url: '',
        shallow_clone: true
      }
    end

    def initialize(args)
      super(args)
    end
  end

  class ConfigRepoTfsMaterial < ConfigRepoMaterial
    def default
      {
        type: 'tfs',
        url: '',
        project_path: '',
        domain: '',
        username: '',
        password: '',
        destination: nil,
        auto_update: true,
        filter: nil
      }
    end

    def initialize(args)
      super(args)
    end
  end

  class ConfigRepoDependencyMaterial < ConfigRepoMaterial
    def default
      {
        type: 'dependency',
        name: 'dependency',
        pipeline: '',
        stage: 'default',
        auto_update: true
      }
    end

    def initialize(args)
      super(args)
    end
  end

  class ConfigRepoEnvironmentVariable < Configuration
    def default
      { secure: false }
    end
  end

  class ConfigRepoParameter < Configuration; end

  class ConfigRepoStage < Configuration
    def default
      {
        name: '',
        approval: {
          type: 'success',
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
      }
    end

    def <<(instance)
      super(instance)
      self.jobs << instance.data if instance.is_a? ConfigRepoJob
    end
  end

  class ConfigRepoJob < Configuration
    def default
      {
        name: '',
        artifacts: [],
        environment_variables: [],
        properties: nil,
        resources: [],
        elastic_profile_id: nil,
        run_count_instance: nil,
        tabs: [],
        tasks: [],
        timeout: 0
        }
    end

    def <<(instance)
      super(instance)
      self.tasks << instance.data if instance.is_a? ConfigRepoExecTask
    end
  end

  class ConfigRepoTask < Configuration; end
  class ConfigRepoExecTask < ConfigRepoTask
    def default
      {
        type: 'exec'
      }
    end

    def initialize(args)
      super(args)
    end
  end
end
