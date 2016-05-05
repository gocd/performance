#!/usr/bin/ruby

def get_go_url
  return "#{ENV["URL"]}/go"
end

def get_dashboard_url
  return "#{get_go_url}/pipelines"
end

def get_agents_url
  return "#{get_go_url}/agents"
end

def get_scenarios
  return { "dashboard" => {"name" => "dashboard", "url" => get_dashboard_url, "count" => 10, "rampup" => 60, "duration" => 300 },
           "agents" => {"name" => "agents", "url" => get_agents_url, "count" => 10, "rampup" => 60, "duration" => 300}}
end
