user node[:activemq][:user] do
  action :create
  system true
  shell  "/bin/false"
end

package "java-1.6.0-openjdk" do
  action :install
end

[
  %w(tanukiwrapper-3.5.9-1.el6.i686 tanukiwrapper-3.5.9-1.el6.i686.rpm),
  %w(activemq-5.5.0-1.el6 activemq-5.5.0-1.el6.noarch.rpm),
  %w(activemq-info-provider-5.5.0-1.el6 activemq-info-provider-5.5.0-1.el6.noarch.rpm),
].each do |rpm|
  remote_file "#{Chef::Config[:file_cache_path]}/#{rpm[1]}" do
    source "#{node[:activemq][:package_host]}/#{rpm[1]}"
    action :create_if_missing
  end
  package rpm[0] do
    action   :install
    source   "#{Chef::Config[:file_cache_path]}/#{rpm[1]}"
    provider Chef::Provider::Package::Rpm
  end
end

%w{activemq.xml broker.ks}.each do |file|
  cookbook_file "/etc/activemq/#{file}" do
    source file
    mode   "0644"
    group  node[:activemq][:user]
    owner  node[:activemq][:user]
  end
end

# http://tickets.opscode.com/browse/CHEF-2345
# The tanuki wrapper script does not provide a nice exit code for status, so the RedHat service
# resource provider cannot properly figure out if the app is started. But the RedHat service
# resource provider sets the status flag to true for every service and ignores any flags that
# tell it that a service does not support status!
service "activemq" do
  action     :start # default provider does not support :enable
  pattern    'activemq'
  supports   :restart => true
  provider   Chef::Provider::Service::Init
  subscribes :restart, resources(:cookbook_file => "/etc/activemq/activemq.xml")
  subscribes :restart, resources(:cookbook_file => "/etc/activemq/broker.ks")
end
