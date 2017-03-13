require './lib/configuration'
require './lib/gocd'
require './lib/looper'
require 'etc'

namespace :postgres do

  task :start => 'postgres:stop' do
    sh("dropdb -U go cruise || true")
    sh(%Q{createdb -U go cruise})
  end

  task :stop do
    verbose false do
      sh %{ service postgresql-9.2 stop } do |ok, res|
        puts 'Stopped PostgreSQL server' if ok
      end
    end
  end

end
