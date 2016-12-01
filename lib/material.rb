require './lib/configuration'
require './lib/material'

include Configuration

module Material
  class Config
    def initialize
      @setup = SetUp.new
      @total_materials = @setup.pipelines.length
      @materials_ratio = @setup.materials_ratio
    end
  end

  class Git < Config
    def repos
      (self.begin..self.end).map {|i| "#{@setup.git_root}/git-repo-gocd.perf#{i}"}
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
end
