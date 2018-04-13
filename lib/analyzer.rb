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
require './lib/gocd'
require './lib/reporter'
require 'json'
require 'pry'
require 'singleton'
require 'markaby'


module Analyzers

  class ResultAnalyzer

    def initialize(file,setup = Configuration::SetUp.new)
      @report_file = file
      @setup = setup
    end

    def tolerable?()
      xml_doc = Nokogiri::XML(File.open(@report_file)).xpath('//httpSample/assertionResult/failure')
      total_failures = 0
      xml_doc.each do |failure_attribute|
        total_failures = total_failures+1 if failure_attribute.text == 'true'
      end
      (total_failures.to_f/xml_doc.count.to_f)*100 <= @setup.failure_tolrance_rate.to_f
    end

    def parse_dashboard_result(filename)
      dashboard = JSON.parse(File.read(filename))
      File.open("#{filename}.txt","w") do |f|
        dashboard['_embedded']['pipeline_groups'].each{ |pg|
          f.puts("Pipeline Group : #{pg['name']}")
          pg['_embedded']['pipelines'].each{ |p|
              f.puts("Pipeline : #{p['name']} Runs : #{p["_embedded"]['instances'].first['label']}")
            }
        }
      end
    end
  end

  class ThreadDumpAnalyzer

    def initialize(server = Configuration::Server.new,
                   setup = Configuration::SetUp.new,
                   client = GoCD::Client.new(server.url))
        @server = server
        @setup = setup
        @client = client
        @Reporter = Reporter::ThreadDumpReporter.instance
    end

    def analyze(prefix)
      pid = `pgrep -f go.jar`.strip
      File.open("#{prefix}.txt", "w"){|file|
        file.write(`jstack -l #{pid}`)
      }
      response = @client.analyze_thread_dump(File.new("#{prefix}.txt","rb"),@setup.fastthread_apikey)
      File.open("#{prefix}_report.json","w"){|f|
        f.write(JSON.pretty_generate(JSON.parse(response.body)))
      }
      @Reporter.report_from("#{prefix}_report.json")
    end

    def generate_report()
      @Reporter.write_to_html()
    end

  end

  class GCAnalyzer

    def initialize(server = Configuration::Server.new,
                   setup = Configuration::SetUp.new,
                   client = GoCD::Client.new(server.url))
        @server = server
        @setup = setup
        @client = client
        @Reporter = Reporter::GCAnalysisReporter.instance
    end

    def analyze(file)
      response = @client.analyze_gc(File.new(file,"rb"),@setup.fastthread_apikey)
      File.open("gc_analysis_result.json","w"){|f|
        f.write(JSON.pretty_generate(JSON.parse(response.body)))
      }
      @Reporter.generate_report("gc_analysis_result.json")
    end

  end

end
