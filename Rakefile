require 'aws'
require 'yaml'
require 'highline/import'

CREDENTIALS = File.expand_path(File.join(File.dirname(__FILE__), '.aws'))
AWS_KEY = File.expand_path(File.join(File.dirname(__FILE__), '.key'))

desc 'Create a named node'
task :start, :node_name do |t, args|
  node = provision_node args.node_name
  wait_for_ssh_connection node
  write_connect_script node, args.node_name
end

desc 'Terminate named node'
task :stop, :node_name do |t, args|
  terminate_node args.node_name
  filename = connect_script_name args.node_name
  File.delete(filename) if File.exists?(filename)
end

desc 'Terminate all running nodes'
task :stop_all do
  terminate_all
end

def wait_for_ssh_connection(node)
  sleep 5 while system("nc -z -v -w 10 #{node.public_dns_name} 22") == false
end

def write_connect_script(node, node_name)
  unless File.exists? AWS_KEY
    aws_key = ask('AWS SSH key? ')
    cp File.expand_path(aws_key), AWS_KEY
    File.chmod(0600, AWS_KEY)
  end
  filename = connect_script_name node_name
  File.open(filename, 'w') do |out|
    out.puts "#!/bin/sh"
    out.puts "ssh -i #{AWS_KEY} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ec2-user@#{node.public_dns_name}"
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
        :image_id => 'ami-6b73562e',
        :key_name => 'us-west',
        :instance_type => 'm1.small'
    )
    wait_while instance, :pending
    instance.add_tag('Name', :value => node_name)
  end
  instance
end

def terminate_node(node_name)
  connect_to_ec2.instances.each do |instance|
    if running_instance? instance, node_name
      puts "Terminating #{node_name}"
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
  ec2 = AWS::EC2.new(aws_credentials)
  ec2.regions['us-west-1']
end

def aws_credentials
  if File.exists? CREDENTIALS
    YAML.load_file CREDENTIALS
  else
    access_key_id = ask('AWS Access Key ID? ')
    secret_access_key = ask('AWS Secret Access Key? ')
    credentials = {:access_key_id => access_key_id.to_s, :secret_access_key => secret_access_key.to_s}
    File.open(CREDENTIALS, 'w') { |out| YAML.dump credentials, out }
    credentials
  end
end
