module LeapCli; module Commands

  desc 'Log in to the specified node with an interactive shell.'
  arg_name 'NAME' #, :optional => false, :multiple => false
  command :ssh do |c|
    c.flag 'ssh', :desc => "Pass through raw options to ssh (e.g. --ssh '-F ~/sshconfig')"
    c.flag 'port', :desc => 'Override ssh port for remote host'
    c.action do |global_options,options,args|
      exec_ssh(:ssh, options, args)
    end
  end

  desc 'Log in to the specified node with an interactive shell using mosh (requires node to have mosh.enabled set to true).'
  arg_name 'NAME'
  command :mosh do |c|
    c.action do |global_options,options,args|
      exec_ssh(:mosh, options, args)
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

  def ssh_config_help_message
    puts ""
    puts "Are 'too many authentication failures' getting you down?"
    puts "Then we have the solution for you! Add something like this to your ~/.ssh/config file:"
    puts "  Host *.#{manager.provider.domain}"
    puts "  IdentityFile ~/.ssh/id_rsa"
    puts "  IdentitiesOnly=yes"
    puts "(replace `id_rsa` with the actual private key filename that you use for this provider)"
  end

  private

  def exec_ssh(cmd, cli_options, args)
    node = get_node_from_args(args, :include_disabled => true)
    port = node.ssh.port
    options = [
      "-o 'HostName=#{node.ip_address}'",
      # "-o 'HostKeyAlias=#{node.name}'", << oddly incompatible with ports in known_hosts file, so we must not use this or non-standard ports break.
      "-o 'GlobalKnownHostsFile=#{path(:known_hosts)}'",
      "-o 'UserKnownHostsFile=/dev/null'"
    ]
    if node.vagrant?
      options << "-i #{vagrant_ssh_key_file}"    # use the universal vagrant insecure key
      options << "-o IdentitiesOnly=yes"         # force the use of the insecure vagrant key
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
    if cli_options[:port]
      port = cli_options[:port]
    end
    if cli_options[:ssh]
      options << cli_options[:ssh]
    end
    ssh = "ssh -l #{username} -p #{port} #{options.join(' ')}"
    if cmd == :ssh
      command = "#{ssh} #{node.domain.full}"
    elsif cmd == :mosh
      command = "MOSH_TITLE_NOPREFIX=1 mosh --ssh \"#{ssh}\" #{node.domain.full}"
    end
    log 2, command

    # exec the shell command in a subprocess
    pid = fork { exec "#{command}" }

    # wait for shell to exit so we can grab the exit status
    _, status = Process.waitpid2(pid)

    if status.exitstatus == 255
      ssh_config_help_message
    elsif status.exitstatus != 0
      exit_now! status.exitstatus, status.exitstatus
    end
  end

end; end