require './lib/gocd'
require './lib/configuration'
require './lib/material'
require './lib/config_repo'
require './lib/looper'
require 'ruby-jmeter'
require './lib/scenario_loader'
require 'process_builder'
require 'pry'
require 'json'

namespace :performance do
  go_server = Configuration::Server.new
  setup = Configuration::SetUp.new
  git = Material::Git.new
  tfs = Material::Tfs.new
  config_repo = Material::ConfigRepo.new

  gocd_client = GoCD::Client.new "#{go_server.secure_url}/go"

  namespace :config do
    task :update do
      duration = setup.config_save_duration
      puts "Saving config by setting the job timeout in a loop #{duration}"
      Looper.run(duration) do
        timeout = rand(60..68)

        puts "Setting job timeout to #{timeout}"
        gocd_client.job_timeout timeout
      end
    end
  end

  namespace :git do
    task :update do # This task updates all the git repos and the config repo too
      duration = setup.git_commit_duration

      Looper.time_out(duration) do
        git.repos.each do |repo|
          verbose false do
            cd repo do
              time = Time.now
              File.write('file', time.to_f)
              sh("git add .;git commit -m 'This is commit at #{time.rfc2822}' --author 'foo <foo@bar.com>'; git gc;")
            end
          end
        end
      end
    end

    task :update_config_repo do # Not using this task now, need to find a better way to handle Material repos and config repos update in single task
      duration = setup.config_repo_commit_duration
      Looper.time_out(duration) do
        verbose false do
          config_repo.update_repo
        end
      end
    end
  end

  namespace :tfs do
    task update: 'tfs:prepare' do
      duration = setup.tfs_commit_duration
      tmp_dir = Dir.tmpdir + '/perf-' + rand.to_s
      workspace_name = "go-ws-#{rand}"
      login = "#{setup.tfs_user},#{setup.tfs_pwd}"
      tee_clc = setup.tee_path

      Looper.time_out(duration) do
        tfs.project_paths.each do |project_path|
          verbose false do
            mkdir_p tmp_dir
            cd tmp_dir do
              sh "#{tee_clc} workspace -new -noprompt -server:#{setup.tfs_url} -login:#{login} #{workspace_name}"
              sh "#{tee_clc} workfold -map -workspace:#{workspace_name} -server:#{setup.tfs_url} -login:#{login} #{project_path} #{tmp_dir}"
              sh "#{tee_clc} get #{tmp_dir} -recursive -noprompt -all -server:#{setup.tfs_url} -login:#{login} #{project_path}"
              file = "#{tmp_dir}/file-#{Time.now.to_i}"
              f = File.new(file, 'w')
              f.write('New Material')
              f.close
              sh "#{tee_clc} add #{file} -login:#{login} #{tmp_dir}; true"
              sh "#{tee_clc} checkin -comment:'Checkin from perf script for file #{file}' -noprompt -login:#{login}"
            end
            sh "#{tee_clc} workfold -unmap -workspace:#{workspace_name} -server:#{setup.tfs_url} -login:#{login} #{tmp_dir}"
            sh "#{tee_clc} workspace -delete #{workspace_name} -server:#{setup.tfs_url} -login:#{login}"
            rm_rf tmp_dir
          end
        end
      end
    end
  end

  task dashboard_to_job_instance: 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.run 'dashboard_to_job_instance', "#{go_server.secure_url}/go"
  end

  task dashboard_to_vsm: 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.run 'dashboard_to_vsm', "#{go_server.secure_url}/go"
  end

  task dashboard_to_pipeline_edit: 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.run 'dashboard_to_pipeline_edit', "#{go_server.secure_url}/go"
  end

  task dashboard_to_compare: 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.run 'dashboard_to_compare', "#{go_server.secure_url}/go"
  end

  task agents_page: 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.run 'agents_spa', "#{go_server.secure_url}/go"
  end

  task dashboard_page_spike: 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.spike 'pipeline_dashboard', "#{go_server.secure_url}/go"
  end

  task dashboard_page: 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.run 'pipeline_dashboard', "#{go_server.secure_url}/go"
  end

  task new_dashboard_page: 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.run_with_access_token 'new_pipeline_dashboard', "#{go_server.secure_url}/go"
  end

  task admin_pages: 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.run 'admin_pages', "#{go_server.secure_url}/go"
  end

  task environments_page: 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.run 'environments_page', "#{go_server.secure_url}/go"
  end

  task pipeline_history: 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.run 'pipeline_history', "#{go_server.secure_url}/go"
  end

  task plugin_status_report: 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.run 'plugin_status_report', "#{go_server.secure_url}/go"
  end

  task admin_pipelines: 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.run 'admin_pipelines', "#{go_server.secure_url}/go"
  end

  task CCTray: 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.run 'CCTray', "#{go_server.secure_url}/go"
  end

  task build_time_analytics: 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.run 'pipeline_build_analytics', "#{go_server.secure_url}/go"
  end

  task global_analytics: 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.run 'pipeline_global_analytics', "#{go_server.secure_url}/go"
  end

  task server_health_messages: 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.run 'server_health_messages', "#{go_server.secure_url}/go"
  end

  task user_summary: 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.run 'user_summary', "#{go_server.secure_url}/go"
  end

  task load_all: 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.run_all "#{go_server.secure_url}/go"
  end

  task monitor: 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.monitor 'perf_mon', go_server.host, "#{go_server.secure_url}/go"
  end

  task :analyze_thread_dump do
    threaddump_analyzer = Analyzers::ThreadDumpAnalyzer.new

    rm_rf 'thread_dumps'
    mkdir_p 'thread_dumps'

    Looper.run(interval: setup.thread_dump_interval.to_i, times: setup.load_test_duration.to_i / setup.thread_dump_interval.to_i) do
      prefix = "threaddump_#{Time.now.strftime('%d_%b_%Y_%H_%M_%S')}"
      cd 'thread_dumps' do
        begin
          threaddump_analyzer.analyze(prefix)
        rescue StandardError => e
          p "Failed to analyze the thread dump for #{prefix}. Failed with exception #{e.message}"
        end
      end
    end
    threaddump_analyzer.generate_report
  end

  task :analyze_gc do
    gc_analyzer = Analyzers::GCAnalyzer.new
    server_dir = "#{setup.server_install_dir}/go-server-#{setup.go_version[0]}"
    cd 'thread_dumps' do
      gc_analyzer.analyze("#{server_dir}/gc.log")
    end
  end

  task :support_api do
    if setup.load_test_duration.to_i > setup.support_api_interval.to_i
      mkdir_p 'support_response'
      Looper.run(interval: setup.support_api_interval.to_i, times: setup.load_test_duration.to_i / setup.support_api_interval.to_i) do
        response = gocd_client.support_page
        File.open("support_response/response_#{Time.now.strftime('%d_%b_%Y_%H_%M_%S')}.json", 'w') do |f|
          f.write(JSON.pretty_generate(JSON.parse(response.body)))
        end
      end
    end
  end

end
