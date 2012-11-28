require 'net/ssh/known_hosts'
require 'tempfile'

module LeapCli; module Commands

  ##
  ## COMMANDS
  ##
  desc 'Node management'
  command :node do |c|
    c.desc 'Create a new configuration file for a node'
    c.command :add do |c|
      c.action do |global_options,options,args|
      end
    end

    c.desc 'Bootstraps a node, setting up ssh keys and installing prerequisites'
    c.arg_name 'node-name', :optional => false, :multiple => false
    c.command :init do |c|
      c.switch 'echo', :desc => 'if set, passwords are visible as you type them (default is hidden)', :negatable => false
      c.action do |global_options,options,args|
        node = get_node_from_args(args)
        ping_node(node)
        save_public_host_key(node)
        update_compiled_ssh_configs
        ssh_connect(node, :bootstrap => true, :echo => options[:echo]) do |ssh|
          ssh.install_authorized_keys
          ssh.install_prerequisites
        end
        log :completed, "node init #{node.name}"
      end
    end

    c.desc 'Renames a node file, and all its related files'
    c.command :mv do |c|
      c.action do |global_options,options,args|
      end
    end

    c.desc 'Removes a node file, and all its related files'
    c.arg_name '<node-name>', :optional => false, :multiple => false
    c.command :rm do |c|
      c.action do |global_options,options,args|
        remove_file!()
      end
    end
  end

  ##
  ## PUBLIC HELPERS
  ##

  #
  # generates the known_hosts file.
  #
  # we do a 'late' binding on the hostnames and ip part of the ssh pub key record in order to allow
  # for the possibility that the hostnames or ip has changed in the node configuration.
  #
  def update_known_hosts
    buffer = StringIO.new
    manager.nodes.keys.sort.each do |node_name|
      node = manager.nodes[node_name]
      hostnames = [node.name, node.domain.internal, node.domain.full, node.ip_address].join(',')
      pub_key = read_file([:node_ssh_pub_key,node.name])
      if pub_key
        buffer << [hostnames, pub_key].join(' ')
        buffer << "\n"
      end
    end
    write_file!(:known_hosts, buffer.string)
  end

  def get_node_from_args(args)
    node_name = args.first
    node = manager.node(node_name)
    assert!(node, "Node '#{node_name}' not found.")
    node
  end

  private

  ##
  ## PRIVATE HELPERS
  ##

  #
  # saves the public ssh host key for node into the provider directory.
  #
  # see `man sshd` for the format of known_hosts
  #
  def save_public_host_key(node)
    log :fetching, "public SSH host key for #{node.name}"
    public_key = get_public_key_for_ip(node.ip_address, node.ssh.port)
    pub_key_path = Path.named_path([:node_ssh_pub_key, node.name])
    if Path.exists?(pub_key_path)
      if public_key == SshKey.load_from_file(pub_key_path)
        log :trusted, "- Public SSH host key for #{node.name} matches previously saved key", :indent => 1
      else
        bail! do
          log 0, :error, "The public SSH host key we just fetched for #{node.name} doesn't match what we have saved previously.", :indent => 1
          log 0, "Remove the file #{pub_key_path} if you really want to change it.", :indent => 2
        end
      end
    elsif public_key.in_known_hosts?(node.name, node.ip_address, node.domain.name)
      log :trusted, "- Public SSH host key for #{node.name} is trusted (key found in your ~/.ssh/known_hosts)"
    else
      puts
      say("This is the SSH host key you got back from node \"#{node.name}\"")
      say("Type        -- #{public_key.bits} bit #{public_key.type.upcase}")
      say("Fingerprint -- " + public_key.fingerprint)
      say("Public Key  -- " + public_key.key)
      if !agree("Is this correct? ")
        bail!
      else
        puts
        write_file! [:node_ssh_pub_key, node.name], public_key.to_s
      end
    end
  end

  def get_public_key_for_ip(address, port=22)
    assert_bin!('ssh-keyscan')
    output = assert_run! "ssh-keyscan -p #{port} -t rsa #{address}", "Could not get the public host key from #{address}:#{port}. Maybe sshd is not running?"
    line = output.split("\n").grep(/^[^#]/).first
    assert! line, "Got zero host keys back!"
    ip, key_type, public_key = line.split(' ')
    return SshKey.load(public_key, key_type)
  end

  def ping_node(node)
    log :pinging, node.name
    assert_run!("ping -W 1 -c 1 #{node.ip_address}", "Could not ping #{node.name} (address #{node.ip_address}). Try again, we only send a single ping.")
  end

end; end