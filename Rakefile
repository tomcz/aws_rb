ROOT = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH.unshift File.join(ROOT, 'lib')

require 'colorize'
require 'ssh_driver'
require 'aws_driver'
require 'highline/import'
require 'rake/clean'
require 'json'

OUTPUT = 'build'
CLEAN << OUTPUT
directory OUTPUT

TARBALL_NAME = 'chef-solo.tar.gz'

task :default => :check_credentials

task :check_credentials do
  @aws = AWSDriver.new(ROOT)
  unless @aws.credentials?
    access_key_id = ask('AWS Access Key ID? ')
    secret_access_key = ask('AWS Secret Access Key? ')
    @aws.save_credentials access_key_id.to_s, secret_access_key.to_s
  end
  unless @aws.ssh_key_file?
    aws_key = ask('SSH Key File? ')
    @aws.save_ssh_key_file aws_key.to_s
  end
end

desc 'Create a named node'
task :start, [:node_name] => [:check_credentials] do |t, args|
  node = @aws.start_node args.node_name
  write_connect_script node
end

desc 'Terminate named node'
task :stop, [:node_name] => [:check_credentials] do |t, args|
  filename = connect_script_name args.node_name
  File.delete(filename) if File.exists?(filename)
  @aws.terminate_node args.node_name
end

desc 'Terminate all running nodes without a name'
task :reaper => :check_credentials do
  @aws.terminate_unnamed
end

desc 'Terminate all running nodes'
task :destroy => :check_credentials do
  Dir[connect_script_name('*')].each { |script| File.delete script }
  @aws.terminate_all
end

desc 'Provision a broker node with chef-solo'
task :provision_broker => [:check_credentials, OUTPUT] do
  provision 'broker', 'chef/nodes/broker.json'
end

desc 'Provision a named node with chef-solo'
task :provision, [:node_name] => [:check_credentials, OUTPUT] do |t, args|
  broker = @aws.start_node 'broker'

  config = open('chef/nodes/node.json') { |fp| JSON.parse fp.read }
  config[:mcollective] = {:stomp_host => broker.hostname}

  config_file = File.join(OUTPUT, 'node.json')
  open(config_file, 'w') { |fp| fp.puts JSON.pretty_generate(config) }

  provision args.node_name, config_file
end

desc 'Run mcollective ping on the broker'
task :mco_ping => :check_credentials do
  node = @aws.start_node 'broker'
  SSHDriver.start(node.hostname, node.user, node.keyfile) do |ssh|
    ssh.exec! 'mco ping'
  end
end

def provision(node_name, config_file)
  node = @aws.start_node node_name
  SSHDriver.start(node.hostname, node.user, node.keyfile) do |ssh|
    install_chef_solo ssh
    config_file_name = File.basename(config_file)
    ssh.upload config_file, "chef/#{config_file_name}"
    ssh.exec! "sudo chef-solo -c ~/chef/solo.rb -j ~/chef/#{config_file_name}"
  end
  write_connect_script node
end

def install_chef_solo(ssh)
  unless ssh.exec('chef-solo --version').success
    ssh.exec! 'sudo yum -y update'
    ssh.exec! 'curl -L http://www.opscode.com/chef/install.sh | sudo bash'
  end
  tarball_file = File.join(OUTPUT, TARBALL_NAME)
  sh "tar cvzf #{tarball_file} chef"
  ssh.exec 'rm -rf chef*'
  ssh.exec "mkdir /tmp/chef-solo"
  ssh.upload tarball_file, TARBALL_NAME
  ssh.exec! "tar xvzf #{TARBALL_NAME}"
end

def write_connect_script(node)
  filename = connect_script_name node.name
  namespace = OpenStruct.new(keyfile: node.keyfile, user: node.user, host: node.hostname)
  results = ERB.new(File.read('lib/connect.sh.erb')).result(namespace.instance_eval { binding })
  File.open(filename, 'w') { |f| f.write(results) }
  File.chmod(0755, filename)
  puts "Connect to #{node.name} using ./#{filename}".green
end

def connect_script_name(node_name)
  "connect_#{node_name}"
end
