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

RELEASES_JSON_URL = ENV['RELEASES_JSON_URL'] || 'https://download.gocd.org/experimental/releases.json'.freeze

def env(variable, default = nil)
  default = yield if block_given?
  ENV[variable] || default
end

def run_soak_test
  env('RUN_SOAK_TEST', 'NO').casecmp('YES').zero? ? true : false
end

def run_config(variable, load = nil, soak = nil)
  (ENV[variable]) || (run_soak_test ? soak : load)
end

module Configuration
  # Setup configuration
  class SetUp
    def pipelines
      (1..number_of_pipelines.to_i).map { |i| "gocd.perf#{i}" }
    end

# This way of calculating total number of pipelines is ugly. Need to fix it to use percentage
# Given toal number of pipelines in a run
# And percentages of pipelines to be running of ecs or k8s or any elastic agents
# The numbers should be calculated accordingly
    def total_pipelines
      number_of_pipelines.to_i + number_of_pipelines_on_ecs_elastic_agents.to_i + number_of_pipelines_on_k8s_elastic_agents.to_i + number_of_pipelines_in_config_repo.to_i + number_of_pipelines_on_azure_elastic_agents.to_i
    end

    def pipelines_run_on_ecs_elastic_agents
      (number_of_pipelines.to_i + 1..number_of_pipelines.to_i + number_of_pipelines_on_ecs_elastic_agents.to_i).map { |i| "gocd.perf#{i}" }
    end

    def pipelines_run_on_k8s_elastic_agents
      (number_of_pipelines.to_i + number_of_pipelines_on_ecs_elastic_agents.to_i + 1..
        number_of_pipelines.to_i + number_of_pipelines_on_ecs_elastic_agents.to_i + number_of_pipelines_on_k8s_elastic_agents.to_i).map { |i| "gocd.perf#{i}" }
    end

    def pipelines_in_config_repo
      (number_of_pipelines.to_i + number_of_pipelines_on_ecs_elastic_agents.to_i + number_of_pipelines_on_k8s_elastic_agents.to_i + 1..
        total_pipelines).map { |i| "gocd.perf#{i}" }
    end

    def pipelines_run_on_azure_elastic_agents
      (number_of_pipelines.to_i + number_of_pipelines_on_ecs_elastic_agents.to_i + number_of_pipelines_on_k8s_elastic_agents.to_i + number_of_pipelines_on_azure_elastic_agents.to_i + 1..
        total_pipelines).map { |i| "gocd.perf#{i}" }
    end

    def agents
      (1..env('NO_OF_AGENTS', 75).to_i).map { |i| "agent-#{i}" }
    end

    def thread_groups
      (1..run_config('NO_OF_THREAD_GROUPS', 4, 1).to_i).to_a
    end

    def throughput_per_minute
      env('THROUGHPUT_PER_MINUTE', '90').to_f
    end

    def thread_count
      env('THREAD_COUNT', '10').to_i
    end

    def users_rampup_time
      env('USERS_RAMPUP_TIME', '100').to_i
    end

    def load_test_duration
      run_config('LOAD_TEST_DURATION', '1200', '86400').to_i
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
      env('INCLUDE_PLUGINS') == 'Y'
    end

    def include_ecs_elastic_agents?
      env('INCLUDE_ECS_EA_PLUGINS') == 'Y'
    end

    def include_k8s_elastic_agents?
      env('INCLUDE_k8S_EA_PLUGINS') == 'Y'
    end

    def include_analytics_plugin?
      env('INCLUDE_ANALYTICS_PLUGIN') == 'Y'
    end

    def include_azure_elastic_agents?
      env('INCLUDE_AZURE_EA_PLUGIN') == 'Y'
    end

    def include_addons?
      env('INCLUDE_ADDONS') == 'Y'
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
      Pathname.new(Dir.pwd + '/tools/TEE-CLC-14.0.3')
    end

    def download_url
      env('DOWNLOAD_URL', 'https://download.gocd.io/experimental')
    end

    def agent_identifier
      env('AGENT_IDENTIFIER', 'perf_on_h2')
    end

    def go_version
      raw_version = env('GO_FULL_VERSION') do
        json = JSON.parse(open(RELEASES_JSON_URL).read)
        json.select { |x| x['go_version'] == ENV['GO_VERSION'] }.sort_by { |a| a['go_build_number'] }.last['go_full_version']
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
        times: load_test_duration / interval
      }
    end

    def git_root
      env('GIT_ROOT', 'gitrepos')
    end

    def config_repo_commit_duration
      interval = env('CONFIG_REPO_COMMIT_INTERVAL', 3600).to_i
      {
        interval: interval,
        times: load_test_duration / interval
      }
    end

    def git_commit_duration
      interval = env('GIT_COMMIT_INTERVAL', 10).to_i
      {
        interval: interval,
        times: load_test_duration / interval
      }
    end

    def tfs_commit_duration
      {
        interval: env('TFS_COMMIT_INTERVAL', 60).to_i,
        times: env('NUMBER_OF_TFS_COMMITS', 2).to_i
      }
    end

    def tee_path
      tee_dir + 'tf'
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

    def newrelic_license_key
      key = env('NEWRELIC_LICENSE_KEY')
      raise 'Please set NEWRELIC_LICENSE_KEY environment variable' unless key
      key
    end

    def aws_secret
      key = env('AWS_SECRET_KEY')
      raise 'Please set AWS_SECRET_KEY environment variable if need to setup ECS plugin' unless key
      key
    end

    def aws_access_key
      key = env('AWS_ACCESS_KEY_ID')
      raise 'Please set AWS_ACCESS_KEY_ID environment variable if need to setup ECS plugin' unless key
      key
    end

    def aws_iam_profile
      key = env('AWS_IAM_PROFILE')
      raise 'Please set AWS_IAM_PROFILE environment variable if need to setup ECS plugin' unless key
      key
    end

    def k8s_token
      key = env('K8s_TOKEN')
      raise 'Please set K8s_TOKEN environment variable if need to setup Kubernetes EA plugin' unless key
      key
    end

    def k8s_ca_cert
      key = env('K8s_CA_CERT')
      raise 'Please set K8s_CA_CERT environment variable if need to setup Kubernetes EA plugin' unless key
      key
    end

    def k8s_namespace
      key = env('K8s_NAMESPACE', 'default')
      raise 'Please set K8s_NAMESPACE environment variable if need to setup Kubernetes EA plugin' unless key
      key
    end

    def k8s_cluster_url
      key = env('K8s_CLUSTER_URL')
      raise 'Please set K8s_CLUSTER_URL environment variable if need to setup Kubernetes EA plugin' unless key
      key
    end

    def ldap_server_ip
      env('LDAP_SERVER_IP', 'localhost')
    end

    def pg_db_host
      env('PG_DB_HOST', 'localhost')
    end

    def pg_db_password
      pwd = env('PG_DB_PASSWORD', nil)
      raise 'Missing PG_DB_PASSWORD environment variable' unless pwd
      pwd
    end

    def analytics_license_key
      env('ANALYTICS_LICENSE_KEY', 'no-license-provided')
    end

    def influxdb_host
      env('INFLUXDB_HOST', 'localhost')
    end

    def thread_dump_interval
      env('THREAD_DUMP_INTERVAL', '60')
    end

    def fastthread_apikey
      key = env('FASTTHREAD_APIKEY')
      raise 'Please set FASTTHREAD_APIKEY to perform thread and GC analysis' unless key
      key
    end

    private

    def number_of_pipelines
      env('NO_OF_PIPELINES', 750)
    end

    def number_of_pipelines_on_ecs_elastic_agents
      env('NO_OF_PIPELINES_ECS_EA', 0)
    end

    def number_of_pipelines_on_k8s_elastic_agents
      env('NO_OF_PIPELINES_K8S_EA', 0)
    end

    def number_of_pipelines_on_azure_elastic_agents
      env('NO_OF_PIPELINES_AZURE_EA', 100)
    end

    def number_of_pipelines_in_config_repo
      env('NO_OF_PIPELINES_CONFIG_REPO', 0)
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

    def loggers
      env('GO_AGENT_LOGGERS', '')
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
      env('PERF_SERVER_SSH_URL', "https://#{host}:#{secure_port}")
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
