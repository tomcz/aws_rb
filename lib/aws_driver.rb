require 'aws'
require 'yaml'
require 'ostruct'
require 'fileutils'

class AWSDriver

  attr_reader :credentials, :ssh_key_file

  # http://aws.amazon.com/amazon-linux-ami/
  AMI_IMAGE    = 'ami-21f9de64'
  EC2_REGION   = 'us-west-1'
  EC2_KEY_NAME = 'us-west'
  AMI_USER     = 'ec2-user'
  AMI_SIZE     = 'm1.small'

  def initialize(config_dir)
    @credentials  = File.join(config_dir, '.aws')
    @ssh_key_file = File.join(config_dir, '.key')
  end

  def start_node(node_name)
    node = provision_node node_name
    wait_for_ssh_connection node.public_dns_name
    OpenStruct.new(:name => node_name, :hostname => node.public_dns_name, :user => AMI_USER, :keyfile => @ssh_key_file)
  end

  def provision_node(node_name)
    conn = connect_to_ec2
    instance = running_instances_with_name(conn, node_name).first
    unless instance
      puts "Starting [#{node_name}] on EC2 ..."
      instance = conn.instances.create(
          :image_id => AMI_IMAGE,
          :key_name => EC2_KEY_NAME,
          :instance_type => AMI_SIZE
      )
      wait_for_aws # too quick!
      wait_until instance, :running
      instance.add_tag('Name', :value => node_name)
    end
    puts "Started [#{node_name}] instance #{instance.id}"
    instance
  end

  def running_instances_with_name(conn, node_name)
    running_instances(conn).filter('tag:Name', node_name)
  end

  def running_instances(conn)
    conn.instances.filter('instance-state-name', 'running')
  end

  def terminate_node(node_name)
    running_instances_with_name(connect_to_ec2, node_name).each { |instance| terminate instance }
  end

  def terminate_unnamed
    running_instances(connect_to_ec2).each do |instance|
      terminate(instance) if instance.tags['Name'].nil?
    end
  end

  def terminate_all
    running_instances(connect_to_ec2).each { |instance| terminate instance }
  end

  def terminate(instance)
    instance_name = instance.tags['Name'] || 'Unnamed'
    puts "Terminating [#{instance_name}] instance #{instance.id}"
    instance.terminate # this make take some time
    wait_until instance, :terminated
  end

  def wait_until(instance, status)
    wait_for_aws while instance.status != status
  end

  def wait_for_ssh_connection(hostname)
    puts "Waiting for SSH server on #{hostname} ..."
    wait_for_aws while !system("nc -z -v -w 10 #{hostname} 22")
  end

  def wait_for_aws
    sleep 5
  end

  def connect_to_ec2
    ec2 = AWS::EC2.new(YAML.load_file(@credentials))
    ec2.regions[EC2_REGION]
  end

  def credentials?
    File.exists? @credentials
  end

  def ssh_key_file?
    File.exists? @ssh_key_file
  end

  def save_credentials(access_key_id, secret_access_key)
    credentials = {:access_key_id => access_key_id, :secret_access_key => secret_access_key}
    File.open(@credentials, 'w') { |out| YAML.dump credentials, out }
    File.chmod(0600, @credentials)
  end

  def save_ssh_key_file(ssh_key_file)
    FileUtils.cp File.expand_path(ssh_key_file), @ssh_key_file
    File.chmod(0600, @ssh_key_file)
  end

end
