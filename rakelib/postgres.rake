require './lib/configuration'
require './lib/gocd'
require './lib/looper'

namespace :postgres do

  task :start => 'postgres:stop' do
    sh(%Q{sudo -H -u postgres bash -c 'rm -rf /var/lib/pgsql/data'})
    sh(%Q{sudo -H -u postgres bash -c 'initdb -D /var/lib/pgsql/data'})
    sh("service postgresql-9.2 start")
    sh(%Q{sudo -H -u postgres bash -c 'sed -i 's/peer/md5/g' /var/lib/pgsql/data/pg_hba.conf'})
    sh(%Q{sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'postgres';"})
    sh("service postgresql-9.2 restart")
    sh(%Q{sudo -H -u postgres bash -c 'createdb -U postgres cruise'})
  end

  task :stop do
    verbose false do
      sh %{ service postgresql-9.2 stop } do |ok, res|
        puts 'Stopped PostgreSQL server' if ok
      end
    end
  end

end
