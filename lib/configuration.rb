#!/usr/bin/ruby
##########################################################################
# Copyright 2016 ThoughtWorks, Inc.
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

def env(variable, default)
  return ENV[variable] || default;
end

module Configuration
  class SetUp
    def pipelines; (1..number_of_pipelines.to_i).map{ |i| "perf#{i}"}; end
    def agents; (1..env("NO_OF_AGENTS", 10).to_i).map { |i| "agent-#{i}" } end
    def git_repository_host; env('GIT_REPOSITORY_HOST', "http://localhost"); end
    def tools_dir; Pathname.new(env('TOOLS_DIR', "./tools")); end
    def jmeter_dir; tools_dir + "apache-jmeter"; end
    def go_version
      raw_version = env('GO_VERSION', nil)

      raise "Missing GO_VERSION environment variable" unless raw_version
      raise %{"GO_VERSION format not right, 
      we need the version and build e.g. 16.0.0-1234"} unless raw_version.include? '-'

      raw_version.split '-'
    end
    def initialize()
      ENV['JMETER_PATH'] = "#{jmeter_dir}/apache-jmeter-3.0/bin/"
    end
    def config_save_duration
      return {interval: env('CONFIG_SAVE_INTERVAL', 5).to_i, times: env('NUMBER_OF_CONFIG_SAVES', 30).to_i} 
    end
    def git_root; env("GIT_ROOT", "gitrepos"); end
    def git_repos; (1..number_of_pipelines.to_i).map{ |i| "#{git_root}/git-repo-#{i}"}; end

    private 
    def number_of_pipelines; env("NO_OF_PIPELINES", 10); end
  end

  class Configuration
    def releases_json; 'https://download.go.cd/experimental/releases.json'; end
    def config_update_interval; env('CONFIG_UPDATE_INTERVAL', 5); end
    def scm_commit_interval; env('SCM_UPDATE_INTERVAL', 5); end
    def server_dir; env('SERVER_DIR', "/tmp"); end
    def git_repos; (1..env('NO_OF_PIPELINES', 10)).map{ |i| "git-repo-#{i}"}; end
    def no_of_commits; env('NO_OF_COMMITS', 1); end
    def gocd_host; "#{server_url}/go"; end
  end

  class Server
    def auth; env('AUTH', nil); end
    def host; env('GOCD_HOST', 'localhost'); end
    def port; env('GO_SERVER_PORT', '8153'); end
    def secure_port; env('GO_SERVER_SSL_PORT', '8154'); end
    def base_url; "http://#{auth ? (auth + '@') : ''}#{host}:#{port}"; end
    def url; "#{base_url}/go"; end
    def secure_url
      env("PERF_SERVER_SSH_URL", "https://localhost:8154") 
    end
    def environment
      {
        'GO_SERVER_SYSTEM_PROPERTIES' => env('GO_SERVER_SYSTEM_PROPERTIES', ''),
        'GO_SERVER_PORT' => port,
        'GO_SERVER_SSL_PORT' => secure_port,
        'SERVER_MEM' => env('SERVER_MEM', '6g'),
        'SERVER_MAX_MEM' => env('SERVER_MAX_MEM', '8g'),
      }
    end
  end
end

