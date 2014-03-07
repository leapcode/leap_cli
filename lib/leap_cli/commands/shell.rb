module LeapCli; module Commands

  desc 'Log in to the specified node with an interactive shell.'
  arg_name 'NAME' #, :optional => false, :multiple => false
  command :ssh do |c|
    c.action do |global_options,options,args|
      exec_ssh(:ssh, args)
    end
  end

  desc 'Log in to the specified node with an interactive shell using mosh (requires node to have mosh.enabled set to true).'
  arg_name 'NAME'
  command :mosh do |c|
    c.action do |global_options,options,args|
      exec_ssh(:mosh, args)
    end
  end

  protected

  #
  # allow for ssh overrides of all commands that use ssh_connect
  #
  def connect_options(options)
    connect_options = {:ssh_options=>{}}
    if options[:port]
      connect_options[:ssh_options][:port] = options[:port]
    end
    if options[:ip]
      connect_options[:ssh_options][:host_name] = options[:ip]
    end
    return connect_options
  end

  private

  def exec_ssh(cmd, args)
    node = get_node_from_args(args, :include_disabled => true)
    options = [
      "-o 'HostName=#{node.ip_address}'",
      # "-o 'HostKeyAlias=#{node.name}'", << oddly incompatible with ports in known_hosts file, so we must not use this or non-standard ports break.
      "-o 'GlobalKnownHostsFile=#{path(:known_hosts)}'",
      "-o 'UserKnownHostsFile=/dev/null'"
    ]
    if node.vagrant?
      options << "-i #{vagrant_ssh_key_file}"    # use the universal vagrant insecure key
      options << '-o IdentitiesOnly=yes'         # only use explicitly configured keys
      options << "-o 'StrictHostKeyChecking=no'" # blindly accept host key and don't save it (since userknownhostsfile is /dev/null)
    else
      options << "-o 'StrictHostKeyChecking=yes'"
    end
    username = 'root'
    if LeapCli.log_level >= 3
      options << "-vv"
    elsif LeapCli.log_level >= 2
      options << "-v"
    end
    ssh = "ssh -l #{username} -p #{node.ssh.port} #{options.join(' ')}"
    if cmd == :ssh
      command = "#{ssh} #{node.name}"
    elsif cmd == :mosh
      command = "MOSH_TITLE_NOPREFIX=1 mosh --ssh \"#{ssh}\" #{node.name}"
    end
    log 2, command
    exec "#{command}"
  end

end; end