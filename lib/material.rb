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

require './lib/configuration'
require './lib/material'

include Configuration

module Material
  class Config
    def initialize
      @setup = SetUp.new
      @total_materials = @setup.total_pipelines
      @materials_ratio = @setup.materials_ratio
    end
  end

  class Git < Config
    def repos
      repo = (self.begin..self.end).map { |i| "#{@setup.git_root}/repo-#{i}" }
      repo.insert(0, "#{@setup.git_root}/repo-common")
      repo.insert(self.end + 1, "#{@setup.git_root}/config-repo-git")
    end

    def end
      @total_materials * @materials_ratio[:git] / 100
    end

    def begin
      1
    end
  end

  class Tfs < Config
    def initialize
      super()
      @git = Material::Git.new
    end

    def project_paths
      (self.begin - @git.end..self.end - @git.end).map { |i| "$/go-perf-#{i}" }
    end

    def end
      @git.end + @total_materials * @materials_ratio[:tfs] / 100
    end

    def begin
      @git.end + 1
    end
  end

  class Distributor
    def initialize
      @setup = SetUp.new
      @git = Material::Git.new
      @tfs = Material::Tfs.new
    end

    def material_for(pipeline)
      suffix = pipeline.gsub(/[^0-9]/, '').to_i
      material = []
      material.push(GitMaterial.new(name: 'material1', url: "#{@setup.git_repository_host}/repo-#{suffix}", destination: 'repo')) if suffix.between?(@git.begin, @git.end)
      material.push(GitMaterial.new(name: 'material2', url: "#{@setup.git_repository_host}/repo-common", destination: 'common')) if [1, 2].include?(suffix % 10)
      #material.push(TfsMaterial.new(name: 'material1', url: "#{@setup.tfs_url}/defaultcollection", username: @setup.tfs_user, password: @setup.tfs_pwd, project_path: "$/go-perf-#{suffix - @git.end}")) if suffix.between?(@tfs.begin, @tfs.end)
      material.push(DependencyMaterial.new(pipeline: "#{pipeline.gsub(/[^a-zA-Z.]/, '')}#{suffix - 1}", name: 'dependency1')) if [3, 4, 5, 7, 8, 9].include?(suffix % 10)
      material.push(DependencyMaterial.new(pipeline: "#{pipeline.gsub(/[^a-zA-Z.]/, '')}#{suffix - 2}", name: 'dependency2')) if [0, 3, 7, 6].include?(suffix % 10)
      material
    end

    def material_for_config_repo(pipeline)
      suffix = pipeline.gsub(/[^0-9]/, '').to_i
      material = []
      material.push(ConfigRepoGitMaterial.new(name: 'material1', url: "#{@setup.git_repository_host}/repo-#{suffix}", destination: 'repo')) if suffix.between?(@git.begin, @git.end)
      material.push(ConfigRepoGitMaterial.new(name: 'material2', url: "#{@setup.git_repository_host}/repo-common", destination: 'common')) if [1, 2].include?(suffix % 10)
      #material.push(ConfigRepoTfsMaterial.new(name: 'material1', url: "#{@setup.tfs_url}/defaultcollection", username: @setup.tfs_user, password: @setup.tfs_pwd, project_path: "$/go-perf-#{suffix - @git.end}")) if suffix.between?(@tfs.begin, @tfs.end)
      material.push(ConfigRepoDependencyMaterial.new(pipeline: "#{pipeline.gsub(/[^a-zA-Z.]/, '')}#{suffix - 1}", name: 'dependency1')) if [3, 4, 5, 7, 8, 9].include?(suffix % 10)
      material.push(ConfigRepoDependencyMaterial.new(pipeline: "#{pipeline.gsub(/[^a-zA-Z.]/, '')}#{suffix - 2}", name: 'dependency2')) if [0, 3, 7, 6].include?(suffix % 10)
      material
    end
  end
end
