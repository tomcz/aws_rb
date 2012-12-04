execute 'install-stomp-rubygem' do
  command 'yum -y install rubygem-stomp-1.2.2 --enablerepo=epel'
  creates '/usr/lib/ruby/gems/1.8/gems/stomp-1.2.2'
end

mcollective_common_package = 'mcollective-common-1.3.1-2.el6'
mcollective_common_filename = 'mcollective-common-1.3.1-2.el6.noarch.rpm'
mcollective_common_local_path = "#{Chef::Config[:file_cache_path]}/#{mcollective_common_filename}"
mcollective_common_remote_path = "#{node[:mcollective][:package_host]}/#{mcollective_common_filename}"

remote_file mcollective_common_local_path do
  source mcollective_common_remote_path
  action :create_if_missing
end

package mcollective_common_package do
  action   :install
  source   mcollective_common_local_path
  provider Chef::Provider::Package::Rpm
end
