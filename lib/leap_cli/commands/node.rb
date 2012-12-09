require 'net/ssh/known_hosts'
require 'tempfile'

module LeapCli; module Commands

  ##
  ## COMMANDS
  ##

  desc 'Node management'
  command :node do |node|
    node.desc 'Create a new configuration file for a node'
    node.long_desc ["If specified, the optional argument seed-options can be used to seed values in the node configuration file.",
                    "The format is property_name:value.",
                    "For example: `leap node add web1 ip_address:1.2.3.4 services:webapp`.",
                    "To set nested properties, property name can contain '.', like so: `leap node add web1 ssh.port:44`",
                    "To set multiple values for a single property, use ',', like so: `leap node add mynode services:webapp,dns`"].join("\n\n")
    node.arg_name '<node-name> [seed-options]' # , :optional => false, :multiple => false
    node.command :add do |add|
      add.switch :local, :desc => 'Make a local testing node (by automatically assigning the next available local IP address). Local nodes are run as virtual machines on your computer.', :negatable => false
      add.action do |global_options,options,args|
        # argument sanity checks
        name = args.first
        assert! name, 'No <node-name> specified.'
        assert! name =~ /^[0-9a-z_-]+$/, "illegal characters used in node name '#{name}'"
        assert_files_missing! [:node_config, node.name]

        # create and seed new node
        node = Config::Object.new
        if options[:local]
          node['ip_address'] = pick_next_vagrant_ip_address
        end
        seed_node_data(node, args[1..-1])

        # write the file
        write_file! [:node_config, name], node.dump_json + "\n"
      end
    end

    node.desc 'Bootstraps a node, setting up SSH keys and installing prerequisite packages'
    node.long_desc "This command prepares a server to be used with the LEAP Platform by saving the server's SSH host key, " +
                   "copying the authorized_keys file, and installing packages that are required for deploying. " +
                   "Node init must be run before deploying to a server, and the server must be running and available via the network. " +
                   "This command only needs to be run once, but there is no harm in running it multiple times."
    node.arg_name '<node-name>' #, :optional => false, :multiple => false
    node.command :init do |init|
      init.switch 'echo', :desc => 'If set, passwords are visible as you type them (default is hidden)', :negatable => false
      init.action do |global_options,options,args|
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

    node.desc 'Renames a node file, and all its related files'
    node.arg_name '<old-name> <new-name>'
    node.command :mv do |mv|
      mv.action do |global_options,options,args|
        node = get_node_from_args(args)
        new_name = args.last
        ensure_dir [:node_files_dir, new_name]
        Path::NODE_PATHS.each do |path|
          rename_file! [path, node.name], [path, new_name]
        end
        remove_directory! [:node_files_dir, node.name]
      end
    end

    node.desc 'Removes a node file, and all its related files'
    node.arg_name '<node-name>' #:optional => false #, :multiple => false
    node.command :rm do |rm|
      rm.action do |global_options,options,args|
        node = get_node_from_args(args)
        (Path::NODE_PATHS + [:node_files_dir]).each do |path|
          remove_file! [path, node.name]
        end
        if node.vagrant?
          vagrant_command("destroy --force", [node.name])
        end
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

  def seed_node_data(node, args)
    args.each do |seed|
      key, value = seed.split(':')
      if value =~ /,/
        value = value.split(',')
      end
      assert! key =~ /^[0-9a-z\._]+$/, "illegal characters used in property '#{key}'"
      if key =~ /\./
        key_parts = key.split('.')
        final_key = key_parts.pop
        current_object = node
        key_parts.each do |key_part|
          current_object[key_part] = Config::Object.new
          current_object = current_object[key_part]
        end
        current_object[final_key] = value
      else
        node[key] = value
      end
    end
  end

end; end