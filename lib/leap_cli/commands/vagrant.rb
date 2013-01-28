require 'ipaddr'
require 'fileutils'

module LeapCli; module Commands

  desc "Manage local virtual machines"
  long_desc "This command provides a convient way to manage Vagrant-based virtual machines. If node-filter argument is missing, the command runs on all local virtual machines. The Vagrantfile is automatically generated in 'test/Vagrantfile'. If you want to run vagrant commands manually, cd to 'test'."
  command :local do |local|
    local.desc 'Starts up the virtual machine(s)'
    local.arg_name 'node-filter', :optional => true #, :multiple => false
    local.command :start do |start|
      start.action do |global_options,options,args|
        vagrant_command(["up", "sandbox on"], args)
      end
    end

    local.desc 'Shuts down the virtual machine(s)'
    local.arg_name 'node-filter', :optional => true #, :multiple => false
    local.command :stop do |stop|
      stop.action do |global_options,options,args|
        vagrant_command("halt", args)
      end
    end

    local.desc 'Resets virtual machine(s) to a pristine state'
    local.arg_name 'node-filter', :optional => true #, :multiple => false
    local.command :reset do |reset|
      reset.action do |global_options,options,args|
        vagrant_command("sandbox rollback", args)
      end
    end

    local.desc 'Destroys the virtual machine(s), reclaiming the disk space'
    local.arg_name 'node-filter', :optional => true #, :multiple => false
    local.command :destroy do |destroy|
      destroy.action do |global_options,options,args|
        vagrant_command("destroy", args)
      end
    end

    local.desc 'Print the status of local virtual machine(s)'
    local.arg_name 'node-filter', :optional => true #, :multiple => false
    local.command :status do |status|
      status.action do |global_options,options,args|
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

  protected

  def vagrant_command(cmds, args)
    vagrant_setup
    cmds = cmds.to_a
    assert_config! 'provider.vagrant.network'
    if args.empty?
      nodes = [""]
    else
      nodes = manager.filter(args)[:local => true].field(:name)
    end
    if nodes.any?
      vagrant_dir = File.dirname(Path.named_path(:vagrantfile))
      exec = ["cd #{vagrant_dir}"]
      cmds.each do |cmd|
        nodes.each do |node|
          exec << "vagrant #{cmd} #{node}"
        end
      end
      execute exec.join('; ')
    else
      bail! "No nodes found. This command only works on nodes with ip_address in the network #{provider.vagrant.network}"
    end
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

  def execute(cmd)
    log 2, :run, cmd
    exec cmd
  end

  def create_vagrant_file
    lines = []
    netmask = IPAddr.new('255.255.255.255').mask(provider.vagrant.network.split('/').last).to_s
    lines << %[Vagrant::Config.run do |config|]
    manager.each_node do |node|
      if node.vagrant?
        lines << %[  config.vm.define :#{node.name} do |config|]
        lines << %[    config.vm.box = "leap-wheezy"]
        lines << %[    config.vm.box_url = "http://cloud.github.com/downloads/leapcode/minimal-debian-vagrant/leap-wheezy.box"]
        lines << %[    config.vm.network :hostonly, "#{node.ip_address}", :netmask => "#{netmask}"]
        lines << %[    config.vm.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]]
        lines << %[    #{leapfile.custom_vagrant_vm_line}] if leapfile.custom_vagrant_vm_line
        lines << %[  end]
      end
    end
    lines << %[end]
    lines << ""
    write_file! :vagrantfile, lines.join("\n")
  end

  def pick_next_vagrant_ip_address
    taken_ips = manager.nodes[:local => true].field(:ip_address)
    if taken_ips.any?
      highest_ip = taken_ips.map{|ip| IPAddr.new(ip)}.max
      new_ip = highest_ip.succ
    else
      new_ip = IPAddr.new(provider.vagrant.network).succ.succ
    end
    return new_ip.to_s
  end

end; end
