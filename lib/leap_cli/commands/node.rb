require 'net/ssh/known_hosts'
require 'tempfile'

module LeapCli; module Commands

  ##
  ## COMMANDS
  ##

  #desc 'Create a new configuration for a node'
  #command :'new-node' do |c|
  #  c.action do |global_options,options,args|
  #  end
  #end

  desc 'Bootstraps a node, setting up ssh keys and installing prerequisites'
  arg_name '<node-name>', :optional => false, :multiple => false
  command :'init-node' do |c|
    c.action do |global_options,options,args|
      node = get_node_from_args(args)
      ping_node(node)
      save_public_host_key(node)
      update_compiled_ssh_configs
      ssh_connect(node, :bootstrap => true) do |ssh|
        ssh.install_authorized_keys
        ssh.install_prerequisites
      end
    end
  end

  desc 'not yet implemented'
  command :'rename-node' do |c|
    c.action do |global_options,options,args|
    end
  end

  desc 'not yet implemented'
  arg_name '<node-name>', :optional => false, :multiple => false
  command :'rm-node' do |c|
    c.action do |global_options,options,args|
      remove_file!()
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
    manager.nodes.values.each do |node|
      hostnames = [node.name, node.domain.internal, node.domain.full, node.ip_address].join(',')
      pub_key = read_file([:node_ssh_pub_key,node.name])
      if pub_key
        buffer << [hostnames, pub_key].join(' ')
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
    progress("Fetching public SSH host key for #{node.name}")
    public_key, key_type = get_public_key_for_ip(node.ip_address)
    pub_key_path = Path.named_path([:node_ssh_pub_key, node.name])
    if Path.exists?(pub_key_path)
      if file_content_equals?(pub_key_path, node_pub_key_contents(key_type, public_key))
        progress("Public SSH host key for #{node.name} has not changed")
      else
        bail!("WARNING: The public SSH host key we just fetched for #{node.name} doesn't match what we have saved previously. Remove the file #{pub_key_path} if you really want to change it.")
      end
    elsif key_in_known_hosts?(public_key, [node.name, node.ip_address, node.domain.name])
      progress("Public SSH host key for #{node.name} is trusted (key found in your ~/.ssh/known_hosts)")
    else
      fingerprint, bits = ssh_key_fingerprint(key_type, public_key)
      puts
      say("This is the SSH host key you got back from node \"#{node.name}\"")
      say("Type        -- #{bits} bit #{key_type.upcase}")
      say("Fingerprint -- " + fingerprint)
      say("Public Key  -- " + public_key)
      if !agree("Is this correct? ")
        bail!
      else
        puts
        write_file!([:node_ssh_pub_key, node.name], node_pub_key_contents(key_type, public_key))
      end
    end
  end

  def get_public_key_for_ip(address)
    assert_bin!('ssh-keyscan')
    output = assert_run! "ssh-keyscan -t rsa #{address}", "Could not get the public host key. Maybe sshd is not running?"
    line = output.split("\n").grep(/^[^#]/).first
    assert! line, "Got zero host keys back!"
    ip, key_type, public_key = line.split(' ')
    return [public_key, key_type]
  end

  #
  # returns true if the particular host_key is found in a "known_hosts" file installed for the current user or on this machine.
  #
  # - host_key: string of ssh public host key
  # - identifiers: an array of identifers (which could be an ip address or hostname)
  #
  def key_in_known_hosts?(host_key, identifiers)
    identifiers.each do |identifier|
      Net::SSH::KnownHosts.search_for(identifier).each do |key|
        # i am not sure what format ssh keys are in, but key.to_pem returns something different than we need.
        # this little bit of magic code will encode correctly. I think the format is base64 encoding of bits, exponent, and modulus.
        key_string = [Net::SSH::Buffer.from(:key, key).to_s].pack("m*").gsub(/\s/, "")
        return true if key_string == host_key
      end
    end
    return false
  end

  #
  # gets a fingerprint for a key string
  #
  # i think this could better be done this way:
  # blob = Net::SSH::Buffer.from(:key, key).to_s
  # fingerprint = OpenSSL::Digest::MD5.hexdigest(blob).scan(/../).join(":")
  #
  def ssh_key_fingerprint(type, key)
    assert_bin!('ssh-keygen')
    file = Tempfile.new('leap_cli_public_key_')
    begin
      file.write(type)
      file.write(" ")
      file.write(key)
      file.close
      output = assert_run!("ssh-keygen -l -f #{file.path}", "Failed to run ssh-keygen on public key.")
      bits, fingerprint, filename, key_type = output.split(' ')
      return [fingerprint, bits]
    ensure
      file.close
      file.unlink
    end
  end

  def ping_node(node)
    progress("Pinging #{node.name}")
    assert_run!("ping -W 1 -c 1 #{node.ip_address}", "Could not ping #{node.name} (address #{node.ip_address}). Try again, we only send a single ping.")
  end

  #
  # returns a string that can be used for the contents of the files/nodes/x/x_ssh_key.pub file
  #
  # We write the file without ipaddress or hostname, because these might change later.
  # The ip and host is added at when compiling the combined known_hosts file.
  #
  def node_pub_key_contents(key_type, public_key)
    [key_type, public_key].join(' ')
  end

end; end