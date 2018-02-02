require './lib/configuration'
require './lib/gocd'
require './lib/looper'
require 'etc'

namespace :postgres do

  task :start => 'postgres:stop' do
    sh("dropdb -U go cruise || true")
    sh(%Q{createdb -U go cruise})
    sh(%Q{psql -U postgres cruise < /var/go/db_dump/perfdb.pgsql})
    sh(%Q{psql -U postgres -d cruise -c "DELETE FROM materials"})
    sh(%Q{psql -U postgres -d cruise -c "DELETE FROM modifiedfiles"})
    sh(%Q{psql -U postgres -d cruise -c "DELETE FROM modifications"})
  end

  task :stop do
    verbose false do
      sh %{ service postgresql-9.4 stop } do |ok, res|
        puts 'Stopped PostgreSQL server' if ok
      end
    end
  end

end
