#
# This file is evaluated just the same as a typical capistrano "deploy.rb"
# For DSL manual, see https://github.com/capistrano/capistrano/wiki
#

MAX_HOSTS = 10

task :install_authorized_keys, :max_hosts => MAX_HOSTS do
  leap.log :updating, "authorized_keys" do
    leap.mkdirs '/root/.ssh'
    upload LeapCli::Path.named_path(:authorized_keys), '/root/.ssh/authorized_keys', :mode => '600'
  end
end

#
# for vagrant nodes, we install insecure vagrant key to authorized_keys2, since deploy
# will overwrite authorized_keys.
#
# why force the insecure vagrant key?
#   if we don't do this, then first time initialization might fail if the user has many keys
#   (ssh will bomb out before it gets to the vagrant key).
#   and it really doesn't make sense to ask users to pin the insecure vagrant key in their
#   .ssh/config files.
#
task :install_insecure_vagrant_key, :max_hosts => MAX_HOSTS do
  leap.log :installing, "insecure vagrant key" do
    leap.mkdirs '/root/.ssh'
    upload LeapCli::Path.vagrant_ssh_pub_key_file, '/root/.ssh/authorized_keys2', :mode => '600'
  end
end

task :install_prerequisites, :max_hosts => MAX_HOSTS do
  bin_dir = File.join(Leap::Platform.leap_dir, 'bin')
  node_init_path = File.join(bin_dir, 'node_init')

  leap.log :running, "node_init script" do
    leap.mkdirs bin_dir
    upload LeapCli::Path.node_init_script, node_init_path, :mode => '500'
    run node_init_path
  end
end

#
# just dummies, used to capture task options
#

task :skip_errors_task, :on_error => :continue, :max_hosts => MAX_HOSTS do
end

task :standard_task, :max_hosts => MAX_HOSTS do
end
