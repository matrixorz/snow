include_recipe "nginx"

['git', 'make', 'g++'].each do |pkg|
  package pkg do
  end
end

admin_ip = search(:node, 'role:admin').first ? search(:node, 'role:admin').first[:ipaddress] : nil
api_ip = search(:node, 'role:api').first ? search(:node, 'role:api').first[:ipaddress] : nil

# Nginx configuration
template '/etc/nginx/sites-available/snow-frontend' do
  source "frontend/nginx.conf.erb"
  owner "root"
  group "root"
  notifies :reload, "service[nginx]"
  variables({
    :api_ip => api_ip || '127.0.0.1',
    :admin_ip => admin_ip || '127.0.0.1'
  })
end

# include_recipe 'deploy_wrapper'
bag = data_bag_item("snow", "main")
env_bag = bag[node.chef_environment]

ssh_known_hosts_entry 'github.com'

deploy_wrapper 'frontend' do
    ssh_wrapper_dir '/home/ubuntu/frontend-ssh-wrapper'
    ssh_key_dir '/home/ubuntu/.ssh'
    ssh_key_data bag["github_private_key"]
    owner "ubuntu"
    group "ubuntu"
    sloppy true
end

# Deployment config
deploy_revision node[:snow][:frontend][:app_directory] do
    user "ubuntu"
    group "ubuntu"
    repo node[:snow][:repo]
    branch node[:snow][:branch]
    ssh_wrapper "/home/ubuntu/frontend-ssh-wrapper/frontend_deploy_wrapper.sh"
    action :deploy
    restart "cd #{node[:snow][:frontend][:app_directory]}/current/web ; npm install --no-bin-link ; node node_modules/bower/bin/bower install ; SEGMENT=#{env_bag['segment']['api_key']} node node_modules/jake/bin/cli.js"
    keep_releases 5
    symlinks({})
    symlink_before_migrate({})
    create_dirs_before_symlink([])
    purge_before_symlink([])
end

# Enable site
nginx_site 'snow-frontend' do
  action :enable
end