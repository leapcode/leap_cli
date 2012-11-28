#
# This file is evaluated just the same as a typical capistrano "deploy.rb"
# For DSL manual, see https://github.com/capistrano/capistrano/wiki
#

require 'supply_drop'

MAX_HOSTS = 10

task :install_authorized_keys, :max_hosts => MAX_HOSTS do
  leap.log :updating, "authorized_keys" do
    leap.mkdirs '/root/.ssh'
    upload LeapCli::Path.named_path(:authorized_keys), '/root/.ssh/authorized_keys', :mode => '600'
  end
end

task :install_prerequisites, :max_hosts => MAX_HOSTS do
  leap.mkdirs puppet_destination
  leap.log :updating, "package list" do
    run "apt-get update"
  end
  leap.log :installing, "required packages" do
    run "DEBIAN_FRONTEND=noninteractive apt-get -q -y -o DPkg::Options::=--force-confold install #{leap.required_packages}"
  end
  leap.mkdirs("/etc/leap", "/srv/leap")
  leap.mark_initialized
end

task :apply_puppet, :max_hosts => MAX_HOSTS do
  raise "now such directory #{puppet_source}" unless File.directory?(puppet_source)
  leap.log :applying, "puppet" do
    puppet.apply
  end
end
