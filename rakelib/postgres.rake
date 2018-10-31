require './lib/configuration'
require './lib/gocd'
require './lib/looper'
require 'etc'

namespace :postgres do
  setup = Configuration::SetUp.new

  task :setup_db do
    sh('dropdb -U postgres cruise || true')
    sh(%(createdb -U postgres cruise))

    if setup.include_analytics_plugin?
      sh('dropdb -U postgres analytics || true')
      sh(%(createdb -U postgres analytics))
    end
  end

  task :stop do
    verbose false do
      sh %( /etc/init.d/postgresql96 stop ) do |ok, _res|
        puts 'Stopped PostgreSQL server' if ok
      end
    end
  end
end
