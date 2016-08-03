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

require 'json'
require 'nokogiri'
require 'cgi'

def cleanup
  rm_rf('jmeter.jmx')
  rm_rf('jmeter.log')
  rm_rf('custom.log')
  rm_rf('perf.jtl')
  rm_rf('jmeter.jtl')
end

def warm_up
  Timeout.timeout(180) do
    loop do
      agents = JSON.parse(open("#{get_url}/api/agents").read)
      break if agents.size == NO_OF_AGENTS
    end
  end
  sleep(180)
end

def destroy pid
  p "destroying child process #{pid}"
  Process.kill 9, pid
  Process.wait pid
end
