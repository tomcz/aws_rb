mcollective_client_package = 'mcollective-client-1.3.1-2.el6'
mcollective_client_filename = 'mcollective-client-1.3.1-2.el6.noarch.rpm'
mcollective_client_local_path = "#{Chef::Config[:file_cache_path]}/#{mcollective_client_filename}"
mcollective_client_remote_path = "#{node[:mcollective][:package_host]}/#{mcollective_client_filename}"

remote_file mcollective_client_local_path do
  source mcollective_client_remote_path
  action :create_if_missing
end

package mcollective_client_package do
  action   :install
  source   mcollective_client_local_path
  provider Chef::Provider::Package::Rpm
end

template "client.cfg" do
  path   "/etc/mcollective/client.cfg"
  source "client.cfg.erb"
  owner  "root"
  group  "root"
  mode   "0644"
end
