require './lib/configuration.rb'

namespace :git do
  setup = Configuration::SetUp.new

  task :prepare => :clean do
    puts "Initializing git repositories, with an initial commit"
    setup.git_repos.each do |repo|
      verbose false do
        mkdir_p repo
        cd repo do
          sh("git init .")
          touch ".git/git-daemon-export-ok"
          touch 'file'
          sh("git add . &> /dev/null")
          sh("git commit -m 'Initial commit' --author 'foo <foo@bar.com>' &> /dev/null")
        end
      end
    end
  end

  task :daemon do
    task :start do
      sh("git daemon --base-path=#{setup.git_root} --detach --syslog --export-all")
    end
    task :stop do
      sh 'pkill -f git-daemon'
    end
  end

  task :clean do
    rm_rf setup.git_root if Dir.exists? setup.git_root
  end
end
