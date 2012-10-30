require 'aws'
require 'yaml'
require 'ostruct'
require 'fileutils'

class AWSDriver

  attr_reader :credentials, :aws_ssh_key

  # http://aws.amazon.com/amazon-linux-ami/
  AMI_IMAGE = 'ami-21f9de64'
  EC2_REGION = 'us-west-1'
  EC2_KEY_NAME = 'us-west'
  AMI_USER = 'ec2-user'
  AMI_SIZE = 'm1.small'

  def initialize(config_dir)
    @credentials = File.join(config_dir, '.aws')
    @aws_ssh_key = File.join(config_dir, '.key')
  end

  def start_node(node_name)
    node = provision_node node_name
    wait_for_ssh_connection node.public_dns_name
    OpenStruct.new(:name => node_name, :hostname => node.public_dns_name, :user => AMI_USER, :keyfile => @aws_ssh_key)
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

  def wait_for_ssh_connection(hostname)
    puts "Waiting for SSH server on #{hostname} ..."
    sleep 5 while !system("nc -z -v -w 10 #{hostname} 22")
  end

  def connect_to_ec2
    ec2 = AWS::EC2.new(YAML.load_file(@credentials))
    ec2.regions[EC2_REGION]
  end

  def save_credentials(access_key_id, secret_access_key)
    credentials = {:access_key_id => access_key_id, :secret_access_key => secret_access_key}
    File.open(@credentials, 'w') { |out| YAML.dump credentials, out }
    File.chmod(0600, @credentials)
  end

  def save_aws_ssh_key(aws_key_file)
    FileUtils.cp File.expand_path(aws_key_file), @aws_ssh_key
    File.chmod(0600, @aws_ssh_key)
  end

end
