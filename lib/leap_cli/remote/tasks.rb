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
# for vagrant nodes, we don't overwrite authorized_keys, because we want to keep the insecure vagrant key.
# instead we install to authorized_keys2, which is also used by sshd.
#
# why?
#   without it, it might be impossible to re-initialize a node.
#
# ok, why is that?
#   when we init a vagrant node, we force it to use the insecure vagrant key, and not the user's keys
#   (so re-initialization would be impossible if authorized_keys doesn't include insecure key).
#
# ok, why force the insecure vagrant key in the first place?
#   if we don't do this, then first time initialization might fail if the user has many keys
#   (ssh will bomb out before it gets to the vagrant key).
#   and it really doesn't make sense to ask users to pin the insecure vagrant key in their
#   .ssh/config files.
#
task :install_authorized_keys2, :max_hosts => MAX_HOSTS do
  leap.log :updating, "authorized_keys2" do
    leap.mkdirs '/root/.ssh'
    upload LeapCli::Path.named_path(:authorized_keys), '/root/.ssh/authorized_keys2', :mode => '600'
  end
end

task :install_prerequisites, :max_hosts => MAX_HOSTS do
  leap.mkdirs LeapCli::PUPPET_DESTINATION
  leap.log :updating, "package list" do
    run "apt-get update"
  end
  leap.log :installing, "required packages" do
    run "DEBIAN_FRONTEND=noninteractive apt-get -q -y -o DPkg::Options::=--force-confold install #{leap.required_packages}"
  end
  run "echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen; locale-gen"
  leap.mkdirs("/etc/leap", "/srv/leap")
  leap.mark_initialized
end

#
# just dummies, used to capture task options
#

task :skip_errors_task, :on_error => :continue, :max_hosts => MAX_HOSTS do
end

task :standard_task, :max_hosts => MAX_HOSTS do
end