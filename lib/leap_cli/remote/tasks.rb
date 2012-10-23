#
# This file is evaluated just the same as a typical capistrano "deploy.rb"
# For DSL manual, see https://github.com/capistrano/capistrano/wiki
#

require 'supply_drop'

MAX_HOSTS = 10

task :install_authorized_keys, :max_hosts => MAX_HOSTS do
  run 'mkdir -p /root/.ssh && chmod 700 /root/.ssh'
  upload LeapCli::Path.named_path(:authorized_keys), '/root/.ssh/authorized_keys', :mode => '600'
end

task :install_prerequisites, :max_hosts => MAX_HOSTS do
  puppet.bootstrap.ubuntu
  #
  # runs this:
  # run "mkdir -p #{puppet_destination}"
  # run "#{sudo} apt-get update"
  # run "#{sudo} apt-get install -y puppet rsync"
  #
end

#task :update_platform, :max_hosts => MAX_HOSTS do
#  puppet.update_code
#end

#task :mk_leap_dir, :max_hosts => MAX_HOSTS do
#  run 'mkdir -p /root/leap/config && chown -R root /root/leap && chmod -R ag-rwx,u+rwX /root/leap'
#end

task :apply_puppet, :max_hosts => MAX_HOSTS do
  raise "now such directory #{puppet_source}" unless File.directory?(puppet_source)
  puppet.apply
end
