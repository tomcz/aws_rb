require 'aws'
require 'yaml'
require 'ostruct'
require 'net/ssh'
require 'highline/import'

# http://aws.amazon.com/amazon-linux-ami/
AMI_IMAGE = 'ami-21f9de64'
EC2_REGION = 'us-west-1'
EC2_KEY_NAME = 'us-west'
AMI_USER = 'ec2-user'
AMI_SIZE = 'm1.small'

CREDENTIALS = File.expand_path(File.join(File.dirname(__FILE__), '.aws'))
AWS_SSH_KEY = File.expand_path(File.join(File.dirname(__FILE__), '.key'))

task :default => :check_credentials

desc 'Create a named node'
task :start, [:node_name] => [:check_credentials] do |t, args|
  node = start_node args.node_name
  write_connect_script node
end

desc 'Terminate named node'
task :stop, [:node_name] => [:check_credentials] do |t, args|
  filename = connect_script_name args.node_name
  File.delete(filename) if File.exists?(filename)
  terminate_node args.node_name
end

desc 'Terminate all running nodes'
task :stop_all => :check_credentials do
  Dir['ssh_*'].each { |script| File.delete script }
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
  node = start_node args.node_name
  connect_to(node) do |ssh|
    install_chef_solo ssh
  end
  write_connect_script node
end

def connect_to(node, &block)
  # use /dev/null as known_hosts to keep EC2 signatures from filling up the normal known_hosts file
  Net::SSH.start(node.hostname, AMI_USER,
      :keys => [AWS_SSH_KEY], :keys_only => true,
      :user_known_hosts_file => ['/dev/null']) do |ssh|
    block.call(ssh)
  end
end

def install_chef_solo(ssh)
  result = ssh_exec ssh, 'chef-solo --version', false
  unless result.success
    ssh_exec ssh, 'sudo yum -y update'
    ssh_exec ssh, 'sudo yum -y install ruby ruby-devel ruby-ri ruby-rdoc gcc gcc-c++ automake autoconf make curl dmidecode rubygems'
    ssh_exec ssh, 'sudo gem install chef --no-ri --no-rdoc'
  end
end

def ssh_exec(ssh, command, check_exit_code = true)
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
  result.success = (result.exit_code == 0)
  puts # output may not end with a new line
  if check_exit_code && !result.success
    raise "FAILED: bad exit code [#{result.exit_code}] for #{command}"
  end
  result
end

def start_node(node_name)
  node = provision_node node_name
  wait_for_ssh_connection node.public_dns_name
  OpenStruct.new(:name => node_name, :hostname => node.public_dns_name)
end

def wait_for_ssh_connection(hostname)
  puts "Waiting for SSH server on #{hostname} ..."
  sleep 5 while !system("nc -z -v -w 10 #{hostname} 22")
end

def write_connect_script(node)
  filename = connect_script_name node.name
  File.open(filename, 'w') do |out|
    out.puts "#!/bin/sh"
    # use /dev/null as known_hosts to keep EC2 signatures from filling up the normal known_hosts file
    out.puts "ssh -i #{AWS_SSH_KEY} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no #{AMI_USER}@#{node.hostname}"
  end
  File.chmod(0755, filename)
  puts "Connect to #{node.name} using ./#{filename}"
end

def connect_script_name(node_name)
  "ssh_" + node_name
end

def provision_node(node_name)
  conn = connect_to_ec2
  instance = conn.instances.find { |i| running_instance? i, node_name }
  unless instance
    puts "Starting #{node_name} on EC2 ..."
    instance = conn.instances.create(
        :image_id => AMI_IMAGE,
        :key_name => EC2_KEY_NAME,
        :instance_type => AMI_SIZE
    )
    wait_while instance, :pending
    instance.add_tag('Name', :value => node_name)
  end
  puts "Started '#{node_name}' instance #{instance.id}"
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
