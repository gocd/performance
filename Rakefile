require "fileutils"

task :start do
  ENV['URL'] = "http://localhost:8153"
  ENV['JMETER_PATH'] = "/usr/local/Cellar/jmeter/2.13/bin/"
  File.delete('jmeter.jmx') if File.exists?('jmeter.jmx')
  File.delete('jmeter.log') if File.exists?('jmeter.log')
  File.delete('custom.log') if File.exists?('custom.log')
  File.delete('jmeter.jtl') if File.exists?('jmeter.jtl')
  File.delete('perf.jtl') if File.exists?('perf.jtl')
  ruby "scripts/run_test.rb"
end
