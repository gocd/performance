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
