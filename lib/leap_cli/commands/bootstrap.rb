require 'net/ssh/known_hosts'
require 'tempfile'

module LeapCli; module Commands

  #desc 'Create a new configuration for a node'
  #command :'new-node' do |c|
  #  c.action do |global_options,options,args|
  #  end
  #end

  desc 'Bootstraps a node, setting up ssh keys and installing prerequisites'
  arg_name '<node-name>', :optional => false, :multiple => false
  command :'init-node' do |c|
    c.action do |global_options,options,args|
      node_name = args.first
      node = manager.node(node_name)
      assert!(node, "Node '#{node_name}' not found.")
      progress("Pinging #{node.name}")
      assert_run!("ping -W 1 -c 1 #{node.ip_address}", "Could not ping #{node_name} (address #{node.ip_address}). Try again, we only send a single ping.")
      install_public_host_key(node)
    end
  end

  desc 'not yet implemented'
  command :'rename-node' do |c|
    c.action do |global_options,options,args|
    end
  end

  desc 'not yet implemented'
  command :'rm-node' do |c|
    c.action do |global_options,options,args|
    end
  end

  #
  # saves the public ssh host key for node into the provider directory.
  #
  # see `man sshd` for the format of known_hosts
  #
  def install_public_host_key(node)
    progress("Fetching public SSH host key for #{node.name}")
    public_key, key_type = get_public_key_for_ip(node.ip_address)
    if key_in_known_hosts?(public_key, [node.name, node.ip_address, node.domain.name])
      progress("Public ssh host key for #{node.name} is already trusted (key found in known_hosts)")
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
        # we write the file without ipaddress or hostname, because these might change later, but we want to keep the same key.
        write_file!([:node_ssh_pub_key, node.name], [key_type, public_key].join(' '))
        update_known_hosts
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

end; end