module LeapCli; module Commands

  desc 'Log in to the specified node with an interactive shell'
  arg_name '<node-name>', :optional => false, :multiple => false
  command :ssh do |c|
    c.action do |global_options,options,args|
      node = get_node_from_args(args)
      options = [
        "-o 'HostName=#{node.ip_address}'",
        "-o 'HostKeyAlias=#{node.name}'",
        "-o 'GlobalKnownHostsFile=#{path(:known_hosts)}'",
        "-o 'StrictHostKeyChecking=yes'"
      ]
      if node.vagrant?
        options << "-i #{vagrant_ssh_key_file}"
      end
      exec "ssh -l root -p #{node.ssh.port} #{options.join(' ')} {node.name}"
    end
  end

end; end