require './lib/configuration'
require './lib/material'

include Configuration

module Material
  class Config
    def initialize
      @setup = SetUp.new
      @total_materials = @setup.pipelines.length + @setup.pipelines_run_on_ecs_elastic_agents.length + @setup.pipelines_run_on_k8s_elastic_agents.length
      @materials_ratio = @setup.materials_ratio
    end
  end

  class Git < Config
    def repos
      repo = (self.begin..self.end).map {|i| "#{@setup.git_root}/git-repo-gocd.perf#{i}"}
      repo.insert(0,"#{@setup.git_root}/git-repo-common")
    end

    def end
      @total_materials*@materials_ratio[:git]/100
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
      (self.begin-@git.end..self.end-@git.end).map {|i| "$/go-perf-#{i}"}
    end

    def end
      @git.end+@total_materials*@materials_ratio[:tfs]/100
    end

    def begin
      @git.end+1
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
      material.push(GitMaterial.new(url: "#{@setup.git_repository_host}/git-repo-#{pipeline}", destination: 'git-repo')) if suffix.between?(@git.begin,@git.end)
      material.push(GitMaterial.new(url: "#{@setup.git_repository_host}/git-repo-common", destination: 'common')) if [1,2].include?(suffix % 10)
      material.push(TfsMaterial.new(url: "#{@setup.tfs_url}/defaultcollection", username: @setup.tfs_user, password: @setup.tfs_pwd, project_path: "$/go-perf-#{suffix-@git.end}")) if suffix.between?(@tfs.begin,@tfs.end)
      material.push(DependencyMaterial.new(pipeline:"#{pipeline.gsub(/[^a-zA-Z.]/, '')}#{suffix-1}", name:"dependency1")) if [3,4,5,7,8,9].include?(suffix % 10)
      material.push(DependencyMaterial.new(pipeline:"#{pipeline.gsub(/[^a-zA-Z.]/, '')}#{suffix-2}", name:"dependency2")) if [0,3,7,6].include?(suffix % 10)

      material
    end

  end
end
