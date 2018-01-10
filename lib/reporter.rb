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
require 'json'
require 'pry'
require 'singleton'
require 'markaby'

module Reporter

  class ThreadDumpReporter
    include Singleton

    @@report = Array.new

    def initialize()
      @reportfile = File.open("ThreadDump_Analysis_report.html", 'w')
      @mab = Markaby::Builder.new
    end

    def report_from(file)
      content = JSON.parse(File.read(file))
      @@report << @mab.div do
        h3 "Thread Dump TimeStamp: #{content['threadDumpReport'][0]['timestamp']}"
        table do
          tr do
            th "Level"
            th "Description"
          end
          if content['threadDumpReport'][0].key?('problem')
            content['threadDumpReport'][0]['problem'].each{|row|
              tr do
                td "#{row['level']}"
                td "#{row['description']}"
              end
            }
          else
            tr do
              td "NONE"
              td "No Issues identified in this Thread Dump"
            end
          end
        end
      end
      puts @@report.to_s

    end

    def write_to_html()
      @mab.html do
        head { title "Thread Dump Analysis Report" }
        body do
          @@report.each{|content|
            div do
              content
            end
          }
        end
      end
      @reportfile.puts @mab.to_s
    end

  end # class

  class GCAnalysisReporter
    include Singleton

    def initialize()
      @reportfile = File.open("GC_Analysis_report.html", 'w')
      @mab = Markaby::Builder.new
    end

    def generate_report(file)
      content = JSON.parse(File.read(file))
      @mab.html do
        head { title "GC Analysis Report" }
        div do
          h1 "Garbage Collection Analysis Report"
          table do
            tr do
              th "Serial No."
              th "Description"
            end
            if content['isProblem'] == 'true'
              content['problem'].each_with_index{|row, index|
                tr do
                  td "#{index}"
                  td "#{row}"
                end
              }
            else
              tr do
                td "NONE"
                td "No Issues identified in this GC"
              end
            end
          end
        end
      end
      @reportfile.puts @mab.to_s
    end

  end # class
end # Module
