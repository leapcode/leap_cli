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
      username = 'root'
      # the echo sets the terminal title. it would be better to do this on the server
      cmd = "ssh -l #{username} -p #{node.ssh.port} #{options.join(' ')} #{node.name}"
      log 2, cmd
      title = "echo -n \"\\033]0;#{username}@#{node.domain.full}\007\""
      exec "#{title} && #{cmd}"
    end
  end

end; end