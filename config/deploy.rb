set :default_environment, {
  'PATH' => '/opt/ruby19/bin:$PATH'
}

set :application, 'errbit'
set :domain_name, 'errbit.apps.bitzesty.com' # set the domain name

set :repository,  'git://github.com/Aaron2Ti/errbit.git'
set :scm, :git

set :deploy_to, "/home/bitzesty/www/#{application}"
set :deploy_via, :remote_cache

server '178.63.34.115', :app, :web, :db, :primary => true

set :user, 'bitzesty'
set :use_sudo, false
set :ssh_options, { :keys => ['certs/bitzesty.pem'], :forward_agent => true }

set :unicorn_pid, "#{shared_path}/pids/unicorn.pid"
set :nginx_site_conf, "/etc/nginx/sites-enabled/#{application}.conf"

namespace :deploy do
  desc 'Restart the app'
  task :restart do
    if 'true' == capture("if [ -e #{unicorn_pid} ]; then echo 'true'; fi").strip
      run "cat #{unicorn_pid} | xargs kill -HUP"
    else
      start
    end
  end

  desc 'Stop unicorns'
  task :stop do
    run "cat #{unicorn_pid} | xargs kill -QUIT"
  end

  desc 'Start unicorns'
  task :start, :roles => :app do
    run "cd #{current_path} && \
           bundle exec unicorn \
             -c #{current_path}/config/unicorn.conf.rb \
             --env #{rails_env} \
             --daemonize"
  end

  desc "Generate unicorn and nginx's config files"
  task :server_config do
    unicorn_tmpl = ERB.new File.read("config/deploy/unicorn.conf.rb.erb")
    nginx_tmpl   = ERB.new File.read("config/deploy/nginx.app.conf.erb")

    run "mkdir -p #{shared_path}/config"

    put unicorn_tmpl.result(binding), "#{shared_path}/config/unicorn.conf.rb"
    put nginx_tmpl.result(binding),   "#{shared_path}/config/nginx.app.conf"

    run "ln -nfs #{shared_path}/config/unicorn.conf.rb \
                 #{release_path}/config/unicorn.conf.rb"
  end

  desc "Nginx deploy introduction"
  task :nginx do
    puts <<-INTRODUCTION
      Contact our system admin running the following commands in order to deploy/undeploy
      the current application.

      Deploy:
        sudo ln -nfs #{shared_path}/config/nginx.app.conf #{nginx_site_conf} && cat /var/run/nginx.pid | xargs sudo kill -HUP

      Undeploy:
        sudo rm #{nginx_site_conf} && cat /var/run/nginx.pid | xargs sudo kill -HUP
    INTRODUCTION
  end
end

require 'bundler/capistrano'

after 'deploy:update_code', 'deploy:server_config'
