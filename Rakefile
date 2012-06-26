require 'aws'
require 'yaml'
require 'highline/import'

CREDENTIALS = File.expand_path(File.join(File.dirname(__FILE__), '.aws'))

desc 'Create a named node'
task :start, :node_name do |t, args|
  node = provision_node args.node_name
  puts node.public_dns_name
end

desc 'Terminate named node'
task :stop, :node_name do |t, args|
  terminate_node args.node_name
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
