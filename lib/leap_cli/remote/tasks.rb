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

BAD_APT_GET_UPDATE = /(BADSIG|NO_PUBKEY|KEYEXPIRED|REVKEYSIG|NODATA)/

task :install_prerequisites, :max_hosts => MAX_HOSTS do
  apt_get = "DEBIAN_FRONTEND=noninteractive apt-get -q -y -o DPkg::Options::=--force-confold"
  apt_get_update = "apt-get update -o Acquire::Languages=none"
  leap.mkdirs Leap::Platform.leap_dir
  run "echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen"
  leap.log :updating, "package list" do
    run apt_get_update do |channel, stream, data|
      # sadly exitcode is unreliable measure if apt-get update hit a failure.
      if data =~ BAD_APT_GET_UPDATE
        LeapCli::Util.bail! do
          LeapCli::Util.log :fatal_error, "in `apt-get update`: #{data}", :host => channel[:host]
        end
      else
        logger.log(1, data, channel[:host])
      end
    end
  end
  leap.log :updating, "server time" do
    run "test -f /usr/sbin/ntpd || #{apt_get} install ntp"
    run "( test -f /etc/init.d/ntp && /etc/init.d/ntp stop ) || true"
    leap.log :running, "ntpd -gq ..." do
      run "test -f /usr/sbin/ntpd && ntpd -gq"
    end
    run "( test -f /etc/init.d/ntp && /etc/init.d/ntp start ) || true"
  end
  leap.log :installing, "required packages" do
    run %[#{apt_get} install $( (egrep -q '(^wheezy|^7\.)' /etc/debian_version && echo #{leap.required_wheezy_packages}) || echo #{leap.required_packages} )]
  end
  #run "locale-gen"
  leap.mkdirs("/etc/leap", "/srv/leap")
  run "chmod 0755 /etc/leap"
  leap.mark_initialized
end

#
# just dummies, used to capture task options
#

task :skip_errors_task, :on_error => :continue, :max_hosts => MAX_HOSTS do
end

task :standard_task, :max_hosts => MAX_HOSTS do
end
