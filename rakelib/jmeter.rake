require './lib/configuration'
require './lib/downloader'

namespace :jmeter do
  setup = Configuration::SetUp.new

  task prepare: :download do
    chmod '+x', setup.jmeter_bin + 'jmeter'
  end

  task :download do
    if !Dir.exist?(setup.jmeter_dir)
      download_dir = setup.tools_dir + 'downloads'
      mkdir_p download_dir unless Dir.exist? download_dir

      puts 'Downloading and setting up JMeter'
      Downloader.new(download_dir) do |q|
        q.add 'https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-5.1.1.zip'
      end.start do |file|
        file.extract_to(setup.tools_dir)
      end

      puts 'Downloading and setting up JMeter plugins'
      Downloader.new(download_dir) do |q|
        q.add 'https://jmeter-plugins.org/downloads/file/JMeterPlugins-Standard-1.4.0.zip'
        q.add 'https://jmeter-plugins.org/downloads/file/JMeterPlugins-Extras-1.4.0.zip'
        q.add 'https://jmeter-plugins.org/downloads/file/JMeterPlugins-ExtrasLibs-1.4.0.zip'
      end.start do |plugin_file|
        plugin_file.extract_to(setup.jmeter_dir)
      end

    elsif
      puts "Using existing Jmeter installation at #{setup.jmeter_dir}"
    end
  end

  task agent: :stop_agent do
    perfmon_dir = setup.tools_dir + 'perfmon'
    mkdir_p perfmon_dir unless Dir.exist? perfmon_dir

    Downloader.new(perfmon_dir) do |q|
      q.add 'http://jmeter-plugins.org/downloads/file/ServerAgent-2.2.1.zip'
    end.start do |agent_zip|
      agent_zip.extract_to(perfmon_dir.to_s)
    end
    Dir.chdir(perfmon_dir) do
      chmod '+x', 'startAgent.sh'
      sh('./startAgent.sh 2>&1 & > /dev/null')
    end
  end

  task :stop_agent do
    verbose false do
      sh %( pkill -f startAgent.sh ) do |ok, _res|
        puts 'Stopped all Jmeter server agents' if ok
      end
      sh %( pkill -f PerfMonAgent ) do |ok, _res|
        puts 'Stopped all Jmeter PerfMonAgent' if ok
      end
    end
  end

  task :clean do
    rm_rf('jmeter.jmx')
    rm_rf('jmeter.log')
    rm_rf('custom.log')
    rm_rf('perf.jtl')
    rm_rf('jmeter.jtl')
  end
end
