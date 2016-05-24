#!/usr/bin/ruby

require 'json'

def get_url path
  return "#{ENV["URL"]}/go#{path}"
end

def get_scenarios
	return JSON.parse(File.read('scripts/load_scenarios.json'))
end
