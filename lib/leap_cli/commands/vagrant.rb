require 'ipaddr'
require 'fileutils'

module LeapCli; module Commands

  desc "Manage local virtual machines"
  long_desc "This command provides a convient way to manage Vagrant-based virtual machines. The Vagrantfile is automatically generated in test/Vagrantfile."
  command :local do |c|
    c.desc 'Starts up the virtual machine'
    c.arg_name 'node-name', :optional => false #, :multiple => false
    c.command :start do |c|
      c.action do |global_options,options,args|
        vagrant_setup
        vagrant_command(["up", "sandbox on"], args)
      end
    end

    c.desc 'Shuts down the virtual machine'
    c.arg_name 'node-name', :optional => false #, :multiple => false
    c.command :stop do |c|
      c.action do |global_options,options,args|
        vagrant_setup
        vagrant_command("halt", args)
      end
    end

    c.desc 'Resets virtual machine to a pristine state'
    c.arg_name 'node-name', :optional => false #, :multiple => false
    c.command :reset do |c|
      c.action do |global_options,options,args|
        vagrant_setup
        vagrant_command("sandbox rollback")
      end
    end

    c.desc 'Destroys the virtual machine, reclaiming the disk space'
    c.arg_name 'node-name', :optional => false #, :multiple => false
    c.command :destroy do |c|
      c.action do |global_options,options,args|
        vagrant_setup
        vagrant_command("destroy", args)
      end
    end

    c.desc 'Print the status of local virtual machine'
    c.arg_name 'node-name', :optional => false #, :multiple => false
    c.command :status do |c|
      c.action do |global_options,options,args|
        vagrant_setup
        vagrant_command("status", args)
      end
    end
  end

  public

  def vagrant_ssh_key_file
    file_path = File.expand_path('../../../vendor/vagrant_ssh_keys/vagrant.key', File.dirname(__FILE__))
    Util.assert_files_exist! file_path
    if File.new(file_path).stat.uid == Process.euid
      # if the vagrant.key file is owned by ourselves, we need to make sure that it is not world readable
      FileUtils.cp file_path, '/tmp/vagrant.key'
      FileUtils.chmod 0600, '/tmp/vagrant.key'
      file_path = '/tmp/vagrant.key'
    end
    return file_path
  end

  private

  def vagrant_setup
    assert_bin! 'vagrant', 'run "sudo gem install vagrant"'
    unless `vagrant gem which sahara`.chars.any?
      log :installing, "vagrant plugin 'sahara'"
      assert_run! 'vagrant gem install sahara'
    end
    create_vagrant_file
  end

  def vagrant_command(cmds, args)
    cmds = cmds.to_a
    assert_config! 'provider.vagrant.network'
    nodes = manager.filter(args)[:local => true].field(:name)
    if nodes.any?
      vagrant_dir = File.dirname(Path.named_path(:vagrantfile))
      exec = ["cd #{vagrant_dir}"]
      cmds.each do |cmd|
        exec << "vagrant #{cmd} #{nodes.join(' ')}"
      end
      execute exec.join('; ')
    else
      bail! "No nodes found. This command only works on nodes with ip_address in the network #{manager.provider.vagrant.network}"
    end
  end

  def execute(cmd)
    log 2, :run, cmd
    exec cmd
  end

  def create_vagrant_file
    lines = []
    netmask = IPAddr.new('255.255.255.255').mask(manager.provider.vagrant.network.split('/').last).to_s
    lines << %[Vagrant::Config.run do |config|]
    manager.each_node do |node|
      if node.vagrant?
        lines << %[  config.vm.define :#{node.name} do |config|]
        lines << %[    config.vm.box = "minimal-wheezy"]
        lines << %[    config.vm.box_url = "http://cloud.github.com/downloads/leapcode/minimal-debian-vagrant/minimal-wheezy.box"]
        lines << %[    config.vm.network :hostonly, "#{node.ip_address}", :netmask => "#{netmask}"]
        lines << %[  end]
      end
    end
    lines << %[end]
    lines << ""
    write_file! :vagrantfile, lines.join("\n")
  end

end; end