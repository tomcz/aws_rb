require 'aws'
require 'yaml'
require 'ostruct'
require 'net/ssh'
require 'highline/import'

AMI_USER = 'ec2-user'
AMI_IMAGE = 'ami-6b73562e'
AMI_SIZE = 'm1.small'

EC2_KEY_NAME = 'us-west'
EC2_REGION = 'us-west-1'

CREDENTIALS = File.expand_path(File.join(File.dirname(__FILE__), '.aws'))
AWS_SSH_KEY = File.expand_path(File.join(File.dirname(__FILE__), '.key'))

task :default => :check_credentials

desc 'Create a named node'
task :start, [:node_name] => [:check_credentials] do |t, args|
  start_node args.node_name
end

desc 'Terminate named node'
task :stop, [:node_name] => [:check_credentials] do |t, args|
  terminate_node args.node_name
  filename = connect_script_name args.node_name
  File.delete(filename) if File.exists?(filename)
end

desc 'Terminate all running nodes'
task :stop_all => :check_credentials do
  terminate_all
end

task :check_credentials do
  unless File.exists? CREDENTIALS
    access_key_id = ask('AWS Access Key ID? ')
    secret_access_key = ask('AWS Secret Access Key? ')
    credentials = {:access_key_id => access_key_id.to_s, :secret_access_key => secret_access_key.to_s}
    File.open(CREDENTIALS, 'w') { |out| YAML.dump credentials, out }
    File.chmod(0600, CREDENTIALS)
  end
  unless File.exists? AWS_SSH_KEY
    aws_key = ask('AWS SSH Key? ')
    cp File.expand_path(aws_key), AWS_SSH_KEY
    File.chmod(0600, AWS_SSH_KEY)
  end
end

desc 'Provision a named node with chef-solo'
task :provision, [:node_name] => [:check_credentials] do |t, args|
  hostname = start_node args.node_name
  Net::SSH.start(hostname, AMI_USER, :keys => [AWS_SSH_KEY], :keys_only => true, :user_known_hosts_file => ['/dev/null']) do |ssh|
    install_chef_solo ssh
  end
end

def install_chef_solo(ssh)
  result = ssh_exec! ssh, 'chef-solo --version', false
  unless result.exit_code == 0
    ssh_exec! ssh, 'sudo yum -y install ruby ruby-devel ruby-ri ruby-rdoc gcc gcc-c++ automake autoconf make curl dmidecode'
    result = ssh_exec! ssh, 'gem --version', false
    unless result.exit_code == 0
      ssh_exec! ssh, 'curl http://production.cf.rubygems.org/rubygems/rubygems-1.8.10.tgz -o /tmp/rubygems-1.8.10.tgz'
      ssh_exec! ssh, 'cd /tmp && tar xzf rubygems-1.8.10.tgz'
      ssh_exec! ssh, 'cd /tmp/rubygems-1.8.10 && sudo ruby setup.rb --no-format-executable'
      ssh_exec! ssh, 'rm -rf /tmp/rubygems-1.8.10*'
    end
    ssh_exec! ssh, 'sudo gem install chef --no-ri --no-rdoc'
  end
end

def ssh_exec!(ssh, command, check_exit_code = true)
  puts ">> #{command}"
  result = OpenStruct.new(:output => '')
  ssh.open_channel do |channel|
    channel.request_pty do |ch,success|
      raise 'FAILED: could not obtain pty' unless success
    end
    channel.exec(command) do |ch,success|
      raise "FAILED: could not execute #{command}" unless success

      channel.on_data do |ch,data|
        result.output += data
        print data
      end

      channel.on_extended_data do |ch,type,data|
        result.output += data
        print data
      end

      channel.on_request("exit-status") do |ch,data|
        result.exit_code = data.read_long
      end

      channel.on_request("exit-signal") do |ch, data|
        result.exit_signal = data.read_long
      end
    end
  end
  ssh.loop
  puts # output may not end with a new line
  if check_exit_code && result.exit_code != 0
    raise "FAILED: bad exit code [#{result.exit_code}] for #{command}"
  end
  result
end

def start_node(node_name)
  node = provision_node node_name
  wait_for_ssh_connection node
  write_connect_script node, node_name
  node.public_dns_name
end

def wait_for_ssh_connection(node)
  puts "Waiting for SSH server on #{node.public_dns_name}"
  sleep 5 while !system("nc -z -v -w 10 #{node.public_dns_name} 22")
end

def write_connect_script(node, node_name)
  filename = connect_script_name node_name
  File.open(filename, 'w') do |out|
    out.puts "#!/bin/sh"
    out.puts "ssh -i #{AWS_SSH_KEY} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no #{AMI_USER}@#{node.public_dns_name}"
  end
  File.chmod(0755, filename)
  puts "Connect to #{node_name} using ./#{filename}"
end

def connect_script_name(node_name)
  "ssh_" + node_name
end

def provision_node(node_name)
  conn = connect_to_ec2
  instance = conn.instances.find { |i| running_instance? i, node_name }
  unless instance
    puts "Starting #{node_name}"
    instance = conn.instances.create(
        :image_id => AMI_IMAGE,
        :key_name => EC2_KEY_NAME,
        :instance_type => AMI_SIZE
    )
    wait_while instance, :pending
    instance.add_tag('Name', :value => node_name)
  end
  puts "Started #{node_name} instance #{instance.id}"
  instance
end

def terminate_node(node_name)
  connect_to_ec2.instances.each do |instance|
    if running_instance? instance, node_name
      puts "Terminating #{node_name} instance #{instance.id}"
      instance.terminate
      wait_while instance, :running
    end
  end
end

def terminate_all
  connect_to_ec2.instances.each do |instance|
    if instance.status == :running
      puts "Terminating #{instance.id}"
      instance.terminate
      wait_while instance, :running
    end
  end
end

def running_instance?(instance, node_name)
  instance.status == :running && instance.tags['Name'] == node_name
end

def wait_while(instance, status)
  sleep 5 while instance.status == status
end

def connect_to_ec2
  ec2 = AWS::EC2.new(YAML.load_file(CREDENTIALS))
  ec2.regions[EC2_REGION]
end
