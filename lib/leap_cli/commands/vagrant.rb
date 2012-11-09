require 'ipaddr'

module LeapCli; module Commands

  desc 'Bring up one or more local virtual machines'
  arg_name '[node-filter]', :optional => true, :multiple => false
  command :'local-up' do |c|
    c.action do |global_options,options,args|
      vagrant_command("up", args)
    end
  end

  desc 'Halt one or more local virtual machines'
  arg_name '[node-filter]', :optional => true, :multiple => false
  command :'local-down' do |c|
    c.action do |global_options,options,args|
      vagrant_command("halt", args)
    end
  end

  desc 'Destroy one or more local virtual machines'
  arg_name '[node-filter]', :optional => true, :multiple => false
  command :'local-reset' do |c|
    c.action do |global_options,options,args|
      vagrant_command("destroy", args)
    end
  end

  public

  def vagrant_ssh_key_file
    file = File.expand_path('../../../vendor/vagrant_ssh_keys/vagrant.key', File.dirname(__FILE__))
    Util.assert_files_exist! file
    return file
  end

  private

  def vagrant_command(cmd, args)
    assert_config! 'provider.vagrant.network'
    create_vagrant_file
    nodes = manager.filter(args)[:local => true].field(:name)
    if nodes.any?
      execute "cd #{File.dirname(Path.named_path(:vagrantfile))}; vagrant #{cmd} #{nodes.join(' ')}"
    else
      bail! "No nodes found. This command only works on nodes with ip_address in the network #{manager.provider.vagrant.network}"
    end
  end

  def execute(cmd)
    progress2 "Running: #{cmd}"
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