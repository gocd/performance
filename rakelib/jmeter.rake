require './lib/configuration'
require './lib/downloader'

namespace :jmeter do
  configuration = Configuration::Configuration.new

  task :prepare => :download do

  end

  task :download do
    if(!Dir.exists?(configuration.jmeter_dir))
      mkdir configuration.jmeter_dir

      puts "Downloading and setting up Jmeter"
      downloader = Downloader.new(configuration.jmeter_dir) { |q|
        q.add "http://mirror.fibergrid.in/apache/jmeter/binaries/apache-jmeter-3.0.zip" 
        q.add "http://jmeter-plugins.org/downloads/file/JMeterPlugins-Standard-1.4.0.zip" 
        q.add "http://jmeter-plugins.org/downloads/file/JMeterPlugins-Extras-1.4.0.zip" 
        q.add "http://jmeter-plugins.org/downloads/file/JMeterPlugins-ExtrasLibs-1.4.0.zip"  
      }
      downloader.start
    elsif
      puts "Using existing Jmeter installation at #{configuration.jmeter_dir}"
    end
  end
end
