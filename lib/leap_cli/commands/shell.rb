module LeapCli; module Commands

  desc 'Log in to the specified node with an interactive shell'
  arg_name '<node-name>', :optional => false, :multiple => false
  command :shell, :ssh do |c|
    c.action do |global_options,options,args|
      node = get_node_from_args(args)
      exec "ssh -l root -o 'HostName=#{node.ip_address}' -o 'HostKeyAlias=#{node.name}' -o 'UserKnownHostsFile=#{path(:known_hosts)}' -o 'StrictHostKeyChecking=yes' -p #{node.ssh.port} #{node.name}"
    end
  end

end; end