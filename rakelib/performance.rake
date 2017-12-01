require './lib/gocd'
require './lib/configuration'
require './lib/material'
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

  gocd_client = GoCD::Client.new go_server.url


  namespace :config do
    task :update do
      duration = setup.config_save_duration
      puts "Saving config by setting the job timeout in a loop #{duration}"
      Looper::run(duration) {
        timeout = 60 + rand(9)

        puts "Setting job timeout to #{timeout}"
        gocd_client.job_timeout timeout
      }
    end
  end

  namespace :git do
    task :update do
      duration = setup.git_commit_duration

      Looper::time_out(duration) {
        git.repos.each do |repo|
          verbose false do
            cd repo do
              time = Time.now
              File.write("file", time.to_f)
              sh("git add .;git commit -m 'This is commit at #{time.rfc2822}' --author 'foo <foo@bar.com>'; git gc;")
            end
          end
        end
      }
    end
  end

  namespace :tfs do
    task :update => 'tfs:prepare' do
      duration = setup.tfs_commit_duration
      tmp_dir = Dir.tmpdir + "/perf-" + rand.to_s
      workspace_name = "go-ws-#{rand.to_s}"
      login = "#{setup.tfs_user},#{setup.tfs_pwd}"
      tee_clc = setup.tee_path

      Looper::time_out(duration) {
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
      }
    end
  end

  task :dashboard_to_job_instance => 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.run 'dashboard_to_job_instance', go_server.url
  end

  task :dashboard_to_vsm => 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.run 'dashboard_to_vsm', go_server.url
  end

  task :dashboard_to_pipeline_edit => 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.run 'dashboard_to_pipeline_edit', go_server.url
  end

  task :dashboard_to_compare => 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.run 'dashboard_to_compare', go_server.url
  end

  task :agents_to_jobs_history => 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.run 'agents_to_jobs_history', go_server.url
  end


  task :dashboard_page_spike => 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.spike 'pipeline_dashboard', go_server.url
  end

  task :dashboard_page => 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.run 'pipeline_dashboard', go_server.url
  end

  task :new_dashboard_page => 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.run 'new_pipeline_dashboard', go_server.url
  end

  task :admin_pages => 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.run 'admin_pages', go_server.url
  end

  task :environments_page => 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.run 'environments_page', go_server.url
  end

  task :pipeline_history => 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.run 'pipeline_history', go_server.url
  end

  task :plugin_status_report => 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.run 'plugin_status_report', go_server.url
  end

  task :admin_pipelines => 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.run 'admin_pipelines', go_server.url
  end

  task :CCTray => 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.run 'CCTray', go_server.url
  end

  task :server_health_messages => 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.run 'server_health_messages', go_server.url
  end

  task :user_summary => 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.run 'user_summary', go_server.url
  end

  task :load_all => 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.run_all go_server.url
  end

  task :monitor => 'jmeter:prepare' do
    loader = ScenarioLoader.new('./scenarios')
    loader.monitor 'perf_mon', go_server.host, go_server.url
  end

  task :support_api do
    if(setup.load_test_duration.to_i > setup.support_api_interval.to_i)
      mkdir_p 'support_response'
      Looper::run({interval:setup.support_api_interval.to_i, times:setup.load_test_duration.to_i/setup.support_api_interval.to_i}) {
        response = gocd_client.support_page
        File.open("support_response/response_#{Time.now.strftime("%d_%b_%Y_%H_%M_%S").to_s}.json","w") do |f|
          f.write(JSON.pretty_generate(JSON.parse(response.body)))
        end
      }
    end
  end

end
