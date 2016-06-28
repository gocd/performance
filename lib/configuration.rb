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

class Configuration
  def env(variable, default)
   return ENV[variable] || default;
  end
  def pipelines; (1..env("NO_OF_PIPELINES", 10).to_i).map{ |i| "perf#{i}"}; end
  def agents; [*1..env("NO_OF_AGENTS", 10).to_i]; end
  def server 
    env('SERVER', 'localhost')
  end
  def port
   env('PORT', 8153) 
  end
  def server_url
    "http://#{server}:#{port}"
  end
  def server_url_ssh
    env("PERF_SERVER_SSH_URL", "https://localhost:8154") 
  end
  def releases_json; 'https://download.go.cd/experimental/releases.json'; end
  def config_update_interval; env('CONFIG_UPDATE_INTERVAL', 5); end
  def scm_commit_interval; env('SCM_UPDATE_INTERVAL', 5); end
  def jmeter_dir; env('JMETER_DIR', "/var/go"); end
  def server_dir; env('SERVER_DIR', "/tmp"); end
  def git_root; env("GIT_ROOT", "/tmp"); end
  def git_repository_server; env('GIT_REPOSITORY_SERVER', "localhost"); end
  def git_repos; (1..env('NO_OF_PIPELINES', 10)).map{ |i| "git-repo-#{i}"}; end
  def no_of_commits; env('NO_OF_COMMITS', 1); end
  def auth; env('AUTH', ''); end
  def gocd_host; "#{server_url}/go"; end
  def initialize()
    ENV['JMETER_PATH'] = "#{jmeter_dir}/apache-jmeter-3.0/bin/"
  end
end
