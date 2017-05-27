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

RELEASES_JSON_URL = 'https://download.gocd.io/experimental/releases.json'

def env(variable, default=nil)
  default = yield if block_given?
  ENV[variable] || default
end

def run_soak_test
  env('RUN_SOAK_TEST', 'NO').upcase == 'YES' ? true : false
end

def run_config(variable, load=nil, soak=nil)
  (ENV[variable]) || (run_soak_test ? soak : load)
end

module Configuration

  # Setup configuration
  class SetUp

    def pipelines
      (1..number_of_pipelines.to_i).map { |i| "gocd.perf#{i}" }
    end

    def agents
      (1..env('NO_OF_AGENTS', 75).to_i).map { |i| "agent-#{i}" }
    end

    def thread_groups
      (1..run_config('NO_OF_THREAD_GROUPS', 4, 1).to_i).to_a
    end

    def load_test_duration
      run_config('LOAD_TEST_DURATION', '1200','86400').to_i
    end

    def git_repository_host
      env('GIT_REPOSITORY_HOST', 'git://localhost')
    end

    def support_api_interval
      env('SUPPORT_API_INTERVAL', '1800')
    end

    def server_install_dir
      Pathname.new(env('SERVER_INSTALL_DIR', '.')) + 'go-server'
    end

    def agents_install_dir
      Pathname.new(env('AGENTS_INSTALL_DIR', '.')) + 'go-agents'
    end

    def include_plugins?
      env('INCLUDE_PLUGINS')=='Y'
    end

    def include_addons?
      env('INCLUDE_ADDONS')=='Y'
    end

    def addons_src_dir
      Pathname.new(env('ADDONS_SRC_DIR', './addons'))
    end

    def plugin_src_dir
      Pathname.new(env('PLUGIN_SRC_DIR', ''))
    end

    def tools_dir
      Pathname.new(env('TOOLS_DIR', './tools'))
    end

    def jmeter_dir
      tools_dir + 'apache-jmeter-3.0'
    end

    def jmeter_bin
      jmeter_dir + 'bin/'
    end

    def tee_dir
      Pathname.new(Dir.pwd+'/tools/TEE-CLC-14.0.3')
    end

    def download_url
      env('DOWNLOAD_URL', 'https://download.gocd.io/experimental')
    end

    def agent_identifier
      env('AGENT_IDENTIFIER', 'perf_on_h2')
    end

    def go_version
      raw_version = env('GO_VERSION') do
          json = JSON.parse(open(RELEASES_JSON_URL).read)
          json.sort {|a, b| a['go_full_version'] <=> b['go_full_version']}.last['go_full_version']
      end

      unless raw_version.include? '-'
        raise 'Wrong GO_VERSION format use 16.X.X-xxxx'
      end

      raw_version.split '-'
    end

    def config_save_duration
      interval = env('CONFIG_SAVE_INTERVAL', 30).to_i
      {
        interval: interval,
        times: load_test_duration/interval
      }
    end

    def git_root
      env('GIT_ROOT', 'gitrepos')
    end

    def git_commit_duration
      interval = env('GIT_COMMIT_INTERVAL', 10).to_i
      {
        interval: interval,
        times: load_test_duration/interval
      }
    end

    def tfs_commit_duration
      {
        interval: env('TFS_COMMIT_INTERVAL', 60).to_i,
        times: env('NUMBER_OF_TFS_COMMITS', 2).to_i
      }
    end

    def tee_path
      tee_dir + "tf"
    end

    def tfs_user
        env('TFS_USER', 'go.tfs.user@gmail.com')
    end

    def tfs_pwd
      pwd = env('TFS_PWD', nil)
      raise 'Missing TFS_PWD environment variable' unless pwd
      pwd
    end

    def tfs_url
      env('TFS_URL', 'https://go-tfs-user.visualstudio.com')
    end

    def materials_ratio
      {
        git: env('GIT_MATERIAL_RATIO', 90).to_i,
        tfs: env('TFS_MATERIAL_RATIO', 10).to_i
      }
    end

    def failure_tolrance_rate
      env('FAILURE_TOLERANCE_RATE', '5').to_i
    end

    def ldap_server_ip
      env('LDAP_SERVER_IP', 'localhost')
    end

    private

    def number_of_pipelines
      env('NO_OF_PIPELINES', 750)
    end
  end

  # Setup configuration
  class Configuration
    def releases_json
      'https://download.gocd.io/experimental/releases.json'
    end

    def config_update_interval
      env('CONFIG_UPDATE_INTERVAL', 30)
    end

    def scm_commit_interval
      env('SCM_UPDATE_INTERVAL', 10)
    end

    def server_dir
      env('SERVER_DIR', '/tmp')
    end



    def gocd_host
      "#{server_url}/go"
    end
  end

  class Agent
    def startup_args
      env('GO_AGENT_SYSTEM_PROPERTIES', '')
    end

    def should_enable_debug_logging
      env('ENABLE_AGENT_DEBUG_LOGS', 'N') == 'Y'
    end
  end

  # Go server configuration
  class Server
    def auth
      env('AUTH', nil)
    end

    def host
      env('GOCD_HOST', '127.0.0.1')
    end

    def port
      env('GO_SERVER_PORT', '8153')
    end

    def secure_port
      env('GO_SERVER_SSL_PORT', '8154')
    end

    def base_url
      "http://#{auth ? (auth + '@') : ''}#{host}:#{port}"
    end

    def url
      "#{base_url}/go"
    end

    def secure_url
      env('PERF_SERVER_SSH_URL', 'https://localhost:8154')
    end

    def environment
      {
        'GO_SERVER_SYSTEM_PROPERTIES' => env('GO_SERVER_SYSTEM_PROPERTIES', ''),
        'GO_SERVER_PORT' => port,
        'GO_SERVER_SSL_PORT' => secure_port,
        'SERVER_MEM' => run_config('SERVER_MEM', '4g', '2g'),
        'SERVER_MAX_MEM' => run_config('SERVER_MAX_MEM', '6g', '4g')
      }
    end
  end
end
