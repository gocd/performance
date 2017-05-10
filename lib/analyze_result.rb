#!/usr/bin/ruby
##########################################################################
# Copyright 2017 ThoughtWorks, Inc.
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

require 'nokogiri'
require './lib/configuration'
require 'pry'

class AnalyzeResult

  def initialize(file)
    @report_file = file
    @setup = Configuration::SetUp.new
  end

  def tolerable?()
    xml_doc = Nokogiri::XML(File.open(@report_file)).xpath('//httpSample/assertionResult/failure')
    total_failures = 0
    xml_doc.each do |failure_attribute|
      total_failures = total_failures+1 if failure_attribute.text == 'true'
    end
    binding.pry
    (total_failures.to_f/xml_doc.count.to_f)*100 <= @setup.failure_tolrance_rate.to_f
  end
end
