require './lib/configuration'
require './lib/downloader'

namespace :jmeter do
  setup = Configuration::SetUp.new

  task :prepare => :download do
  end

  task :download do
    if(!Dir.exists?(setup.jmeter_dir))
      download_dir = setup.tools_dir + "downloads"
      mkdir_p download_dir if !Dir.exists? download_dir

      puts "Downloading and setting up JMeter"
      Downloader.new(download_dir) { |q|
        q.add "http://mirror.fibergrid.in/apache/jmeter/binaries/apache-jmeter-3.0.zip" 
      }.start {|file|
        file.extractTo(setup.tools_dir)

        puts "Downloading and setting up JMeter plugins"
        Downloader.new(download_dir) { |q|
          q.add "http://jmeter-plugins.org/downloads/file/JMeterPlugins-Standard-1.4.0.zip" 
          q.add "http://jmeter-plugins.org/downloads/file/JMeterPlugins-Extras-1.4.0.zip" 
          q.add "http://jmeter-plugins.org/downloads/file/JMeterPlugins-ExtrasLibs-1.4.0.zip"  
        }.start {|plugin_file|
          plugin_file.extractTo(setup.jmeter_dir)
        }
      }
    elsif
      puts "Using existing Jmeter installation at #{setup.jmeter_dir}"
    end
  end

  task :agent do
    if !Dir.exists?(setup.jmeter_dir)
      Dir.chdir(setup.jmeter_dir) do
        Downloader.new {|q|
          q.add 'http://jmeter-plugins.org/downloads/file/ServerAgent-2.2.1.zip'
        }.start {|agent_zip|
          agent_zip.extractTo('perf_mon_agent')
        }
        sh("perf_mon_agent/startAgent.sh 2>&1 & > /dev/null")
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
