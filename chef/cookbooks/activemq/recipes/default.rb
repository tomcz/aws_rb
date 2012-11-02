user node[:activemq][:user] do
  action :create
  system true
  shell  "/bin/false"
end

package "java-1.6.0-openjdk" do
  action :install
end

remote_file "#{Chef::Config[:file_cache_path]}/tanukiwrapper-3.5.9-1.el6.i686.rpm" do
  source "http://archives.watchitlater.com/rpms/tanukiwrapper-3.5.9-1.el6.i686.rpm"
  action :create_if_missing
end

remote_file "#{Chef::Config[:file_cache_path]}/activemq-5.5.0-1.el6.noarch.rpm" do
  source "http://archives.watchitlater.com/rpms/activemq-5.5.0-1.el6.noarch.rpm"
  action :create_if_missing
end

remote_file "#{Chef::Config[:file_cache_path]}/activemq-info-provider-5.5.0-1.el6.noarch.rpm" do
  source "http://archives.watchitlater.com/rpms/activemq-info-provider-5.5.0-1.el6.noarch.rpm"
  action :create_if_missing
end

package "tanukiwrapper-3.5.9-1.el6.i686" do
  action   :install
  source   "#{Chef::Config[:file_cache_path]}/tanukiwrapper-3.5.9-1.el6.i686.rpm"
  provider Chef::Provider::Package::Rpm
end

package "activemq-5.5.0-1.el6" do
  action   :install
  source   "#{Chef::Config[:file_cache_path]}/activemq-5.5.0-1.el6.noarch.rpm"
  provider Chef::Provider::Package::Rpm
end

package "activemq-info-provider-5.5.0-1.el6" do
  action   :install
  source   "#{Chef::Config[:file_cache_path]}/activemq-info-provider-5.5.0-1.el6.noarch.rpm"
  provider Chef::Provider::Package::Rpm
end

cookbook_file "/etc/activemq/activemq.xml" do
  source "activemq.xml"
  mode   "0644"
  group  node[:activemq][:user]
  owner  node[:activemq][:user]
end

cookbook_file "/etc/activemq/broker.ks" do
  source "broker.ks"
  mode   "0644"
  group  node[:activemq][:user]
  owner  node[:activemq][:user]
end

# http://tickets.opscode.com/browse/CHEF-2345
# The tanuki wrapper script does not provide a nice exit code for status, so the RedHat service
# resource provider cannot properly figure out if the app is started. But the RedHat service
# resource provider sets the status flag to true for every service and ignores any flags that
# tell it that a service does not support status!
service "activemq" do
  action     :start
  pattern    'activemq'
  supports   :restart => true
  provider   Chef::Provider::Service::Init
  subscribes :restart, resources(:cookbook_file => "/etc/activemq/activemq.xml")
  subscribes :restart, resources(:cookbook_file => "/etc/activemq/broker.ks")
end
