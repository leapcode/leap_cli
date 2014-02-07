#
# MACROS
# these are methods available when eval'ing a value in the .json configuration
#
# This module is included in Config::Object
#

module LeapCli; module Config
  module Macros
    ##
    ## NODES
    ##

    #
    # the list of all the nodes
    #
    def nodes
      global.nodes
    end

    #
    # returns a list of nodes that match the same environment
    #
    # if @node.environment is not set, we return other nodes
    # where environment is not set.
    #
    def nodes_like_me
      nodes[:environment => @node.environment]
    end

    ##
    ## FILES
    ##

    class FileMissing < Exception
      attr_accessor :path, :options
      def initialize(path, options={})
        @path = path
        @options = options
      end
      def to_s
        @path
      end
    end

    #
    # inserts the contents of a file
    #
    def file(filename, options={})
      if filename.is_a? Symbol
        filename = [filename, @node.name]
      end
      filepath = Path.find_file(filename)
      if filepath
        if filepath =~ /\.erb$/
          ERB.new(File.read(filepath), nil, '%<>').result(binding)
        else
          File.read(filepath)
        end
      else
        raise FileMissing.new(Path.named_path(filename), options)
        ""
      end
    end

    #
    # like #file, but allow missing files
    #
    def try_file(filename)
      return file(filename)
    rescue FileMissing
      return nil
    end

    #
    # returns what the file path will be, once the file is rsynced to the server.
    # an internal list of discovered file paths is saved, in order to rsync these files when needed.
    #
    # notes:
    #
    # * argument 'path' is relative to Path.provider/files or Path.provider_base/files
    # * the path returned by this method is absolute
    # * the path stored for use later by rsync is relative to Path.provider
    # * if the path does not exist locally, but exists in provider_base, then the default file from
    #   provider_base is copied locally. this is required for rsync to work correctly.
    #
    def file_path(path)
      if path.is_a? Symbol
        path = [path, @node.name]
      end
      actual_path = Path.find_file(path)
      if actual_path.nil?
        Util::log 2, :skipping, "file_path(\"#{path}\") because there is no such file."
        nil
      else
        if actual_path =~ /^#{Regexp.escape(Path.provider_base)}/
          # if file is under Path.provider_base, we must copy the default file to
          # to Path.provider in order for rsync to be able to sync the file.
          local_provider_path = actual_path.sub(/^#{Regexp.escape(Path.provider_base)}/, Path.provider)
          FileUtils.mkdir_p File.dirname(local_provider_path), :mode => 0700
          FileUtils.install actual_path, local_provider_path, :mode => 0600
          Util.log :created, Path.relative_path(local_provider_path)
          actual_path = local_provider_path
        end
        if File.directory?(actual_path) && actual_path !~ /\/$/
          actual_path += '/' # ensure directories end with /, important for building rsync command
        end
        relative_path = Path.relative_path(actual_path)
        @node.file_paths << relative_path
        @node.manager.provider.hiera_sync_destination + '/' + relative_path
      end
    end

    #
    # inserts a named secret, generating it if needed.
    #
    # manager.export_secrets should be called later to capture any newly generated secrets.
    #
    # +length+ is the character length of the generated password.
    #
    def secret(name, length=32)
      @manager.secrets.set(name, Util::Secret.generate(length))
    end

    #
    # inserts an hexidecimal secret string, generating it if needed.
    #
    # +bit_length+ is the bits in the secret, (ie length of resulting hex string will be bit_length/4)
    #
    def hex_secret(name, bit_length=128)
      @manager.secrets.set(name, Util::Secret.generate_hex(bit_length))
    end

    #
    # return a fingerprint for a x509 certificate
    #
    def fingerprint(filename)
      "SHA256: " + X509.fingerprint("SHA256", Path.named_path(filename))
    end

    ##
    ## HOSTS
    ##

    #
    # records the list of hosts that are encountered for this node
    #
    def hostnames(nodes)
      @referenced_nodes ||= ObjectList.new
      if nodes.is_a? Config::Object
        nodes = ObjectList.new nodes
      end
      nodes.each_node do |node|
        @referenced_nodes[node.name] ||= node
      end
      return nodes.values.collect {|node| node.domain.name}
    end

    #
    # Generates entries needed for updating /etc/hosts on a node, but only including the IPs of the
    # other nodes we have encountered. Also, for virtual machines, use the local address if this
    # @node is in the same location.
    #
    def hosts_file
      if @referenced_nodes && @referenced_nodes.any?
        hosts = {}
        my_location = @node['location'] ? @node['location']['name'] : nil
        @referenced_nodes.each_node do |node|
          next if node.name == @node.name
          hosts[node.name] = {'ip_address' => node.ip_address, 'domain_internal' => node.domain.internal, 'domain_full' => node.domain.full}
          node_location = node['location'] ? node['location']['name'] : nil
          if my_location == node_location
            if facts = @node.manager.facts[node.name]
              if facts['ec2_public_ipv4']
                hosts[node.name]['ip_address'] = facts['ec2_public_ipv4']
              end
            end
          end
        end
        #hosts = @referenced_nodes.pick_fields("ip_address", "domain.internal", "domain.full")
        return hosts
      else
        return nil
      end
    end

    ##
    ## STUNNEL
    ##

    #
    # stunnel configuration for the client side.
    #
    # +node_list+ is a ObjectList of nodes running stunnel servers.
    #
    # +port+ is the real port of the ultimate service running on the servers
    # that the client wants to connect to.
    #
    # About ths stunnel puppet names:
    #
    # * accept_port is the port on localhost to which local clients
    #   can connect. it is auto generated serially.
    # * connect_port is the port on the stunnel server to connect to.
    #   it is auto generated from the +port+ argument.
    #
    #  The network looks like this:
    #
    #  |------ stunnel client ---------------| |--------- stunnel server -----------------------|
    #  consumer app -> localhost:accept_port -> server:connect_port -> server:port -> service app
    #
    # generates an entry appropriate to be passed directly to
    # create_resources(stunnel::service, hiera('..'), defaults)
    #
    def stunnel_client(node_list, port, options={})
      @next_stunnel_port ||= 4000
      hostnames(node_list) # record the hosts
      node_list.values.inject(Config::ObjectList.new) do |hsh, node|
        if node.name != self.name || options[:include_self]
          hsh["#{node.name}_#{port}"] = Config::Object[
            'accept_port', @next_stunnel_port,
            'connect', node.domain.internal,
            'connect_port', stunnel_port(port)
          ]
          @next_stunnel_port += 1
        end
        hsh
      end
    end

    #
    # generates a stunnel server entry.
    #
    # +port+ is the real port targeted service.
    #
    def stunnel_server(port)
      {"accept" => stunnel_port(port), "connect" => "127.0.0.1:#{port}"}
    end

    #
    # maps a real port to a stunnel port (used as the connect_port in the client config
    # and the accept_port in the server config)
    #
    def stunnel_port(port)
      port = port.to_i
      if port < 50000
        return port + 10000
      else
        return port - 10000
      end
    end

    ##
    ## HAPROXY
    ##

    #
    # creates a hash suitable for configuring haproxy. the key is the node name of the server we are proxying to.
    #
    # * node_list - a hash of nodes for the haproxy servers
    # * stunnel_client - contains the mappings to local ports for each server node.
    # * non_stunnel_port - in case self is included in node_list, the port to connect to.
    #
    # 1000 weight is used for nodes in the same location.
    # 100 otherwise.
    #
    def haproxy_servers(node_list, stunnel_clients, non_stunnel_port=nil)
      default_weight = 10
      local_weight = 100

      # record the hosts_file
      hostnames(node_list)

      # create a simple map for node name -> local stunnel accept port
      accept_ports = stunnel_clients.inject({}) do |hsh, stunnel_entry|
        name = stunnel_entry.first.sub /_[0-9]+$/, ''
        hsh[name] = stunnel_entry.last['accept_port']
        hsh
      end

      # if one the nodes in the node list is ourself, then there will not be a stunnel to it,
      # but we need to include it anyway in the haproxy config.
      if node_list[self.name] && non_stunnel_port
        accept_ports[self.name] = non_stunnel_port
      end

      # create the first pass of the servers hash
      servers = node_list.values.inject(Config::ObjectList.new) do |hsh, node|
        weight = default_weight
        if self['location'] && node['location']
          if self.location['name'] == node.location['name']
            weight = local_weight
          end
        end
        hsh[node.name] = Config::Object[
          'backup', false,
          'host', 'localhost',
          'port', accept_ports[node.name] || 0,
          'weight', weight
        ]
        hsh
      end

      # if there are some local servers, make the others backup
      if servers.detect{|k,v| v.weight == local_weight}
        servers.each do |k,server|
          server['backup'] = server['weight'] == default_weight
        end
      end

      return servers
    end

    ##
    ## SSH
    ##

    #
    # Creates a hash from the ssh key info in users directory, for use in
    # updating authorized_keys file. Additionally, the 'monitor' public key is
    # included, which is used by the monitor nodes to run particular commands
    # remotely.
    #
    def authorized_keys
      hash = {}
      keys = Dir.glob(Path.named_path([:user_ssh, '*']))
      keys.sort.each do |keyfile|
        ssh_type, ssh_key = File.read(keyfile).strip.split(" ")
        name = File.basename(File.dirname(keyfile))
        hash[name] = {
          "type" => ssh_type,
          "key" => ssh_key
        }
      end
      ssh_type, ssh_key = File.read(Path.named_path(:monitor_pub_key)).strip.split(" ")
      hash[Leap::Platform.monitor_username] = {
        "type" => ssh_type,
        "key" => ssh_key
      }
      hash
    end

    def known_hosts_file
      return nil unless @referenced_nodes
      entries = []
      @referenced_nodes.each_node do |node|
        hostnames = [node.name, node.domain.internal, node.domain.full, node.ip_address].join(',')
        pub_key   = Util::read_file([:node_ssh_pub_key,node.name])
        if pub_key
          entries << [hostnames, pub_key].join(' ')
        end
      end
      entries.join("\n")
    end

    ##
    ## UTILITY
    ##

    class AssertionFailed < Exception
      attr_accessor :assertion
      def initialize(assertion)
        @assertion = assertion
      end
      def to_s
        @assertion
      end
    end

    def assert(assertion)
      if instance_eval(assertion)
        true
      else
        raise AssertionFailed.new(assertion)
      end
    end

  end
end; end
