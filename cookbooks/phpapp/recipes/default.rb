#
# Cookbook:: phpapp
# Recipe:: default
#
# Copyright:: 2018, The Authors, All Rights Reserved.

work_dir = '/var/www/html'
app_dir = '/var/www/html/app'
repo_url = 'git://github.com/Saritasa/simplephpapp.git'
branch_repo = 'develop'

execute "clean cache repo" do
  command "sudo yum clean all |sudo rm -rf /var/cache/yum "
end


include_recipe "apache2"

execute "update repo epel" do
  command "sudo yum -y update"
end

include_recipe "yum-epel::default"

execute "update repo epel" do
  command "sudo yum -y update"
end

include_recipe "yum-remi-chef::remi-php71"

execute "update repo remi" do
  command "sudo yum -y update"
end


include_recipe "yarn::default"


apache_site "default" do
  enable true
end

['php','php-common','php-opcache', 'php-mcrypt', 'php-cli', 'php-gd', 'php-curl', 'php-mysql', 'composer', 'git'].each do |p|
  package p do
    action :install
  end
end

execute "Remove old source code" do
  cwd work_dir
  command "sudo rm -rf #{app_dir}"
  only_if { ::File.directory?("#{app_dir}") }
end



git app_dir do
  repository repo_url
  revision branch_repo
  action :sync
end

execute "copy env file" do
  cwd app_dir
  command "sudo cp .env.example .env"
  not_if { ::File.exist?("#{app_dir}/.env") }
end

execute "Install composer dependencies" do
  cwd app_dir
  command "sudo composer install"
  only_if { ::File.directory?("#{app_dir}") }
end

execute "run php dependencies" do
  cwd app_dir
  command "sudo php artisan key:generate"
  only_if { ::File.directory?("#{app_dir}") }
end


yarn_install app_dir do
  user 'root'
  action :run
end

yarn_run 'production' do
  user 'root'
  dir app_dir
  action :run
end

cookbook_file "Copy httpd conf" do  
  group "root"
  mode "0755"
  owner "root"
  path "/etc/httpd/conf/httpd.conf"
  source "httpd.conf" 
  action :create 
end

execute "chown-apache" do
  command "sudo chown -R apache:apache /var/www/html/app"
  user "root"
  action :run
  not_if "stat -c %U /var/www/html/app |grep apache"
end

execute "selinux permission" do
  command "sudo setenforce 0"
  user "root"
  action :run
end


service "httpd" do
  action :restart
end

