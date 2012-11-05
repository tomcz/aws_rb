mcollective_server_package = 'mcollective-1.3.1-2.el6'
mcollective_server_filename = 'mcollective-1.3.1-2.el6.noarch.rpm'
mcollective_server_local_path = "#{Chef::Config[:file_cache_path]}/#{mcollective_server_filename}"
mcollective_server_remote_path = "#{node[:mcollective][:package_host]}/#{mcollective_server_filename}"

remote_file mcollective_server_local_path do
  source mcollective_server_remote_path
  action :create_if_missing
end

package mcollective_server_package do
  action   :install
  source   mcollective_server_local_path
  provider Chef::Provider::Package::Rpm
end

template "server.cfg" do
  path   "/etc/mcollective/server.cfg"
  source "server.cfg.erb"
  owner  "root"
  group  "root"
  mode   "0644"
end

service "mcollective" do
  action     [:enable, :start]
  supports   :status => true, :restart => true
  subscribes :restart, resources(:template => "server.cfg")
end
