require './lib/configuration'
require './lib/gocd'
require './lib/looper'
require 'etc'

namespace :postgres do
  task :setup_db do
    sh('dropdb -U go cruise || true')
    sh(%(createdb -U go cruise))
  end

  task :stop do
    verbose false do
      sh %( service postgresql-9.5 stop ) do |ok, _res|
        puts 'Stopped PostgreSQL server' if ok
      end
    end
  end
end
