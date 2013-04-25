require 'fileutils'

module LeapCli; module Path

  #
  # all the named paths, relative to provider directory.
  #
  NAMED_PATHS = {
    # directories
    :hiera_dir        => 'hiera',
    :files_dir        => 'files',
    :nodes_dir        => 'nodes',
    :services_dir     => 'services',
    :tags_dir         => 'tags',
    :node_files_dir   => 'files/nodes/#{arg}',

    # input config files
    :common_config    => 'common.json',
    :provider_config  => 'provider.json',
    :secrets_config   => 'secrets.json',
    :node_config      => 'nodes/#{arg}.json',
    :service_config   => 'services/#{arg}.json',
    :tag_config       => 'tags/#{arg}.json',

    # input templates
    :provider_json_template => 'files/service-definitions/provider.json.erb',
    :eip_service_json_template => 'files/service-definitions/#{arg}/eip-service.json.erb',

    # output files
    :user_ssh         => 'users/#{arg}/#{arg}_ssh.pub',
    :user_pgp         => 'users/#{arg}/#{arg}_pgp.pub',
    :known_hosts      => 'files/ssh/known_hosts',
    :authorized_keys  => 'files/ssh/authorized_keys',
    :ca_key           => 'files/ca/ca.key',
    :ca_cert          => 'files/ca/ca.crt',
    :client_ca_key    => 'files/ca/client_ca.key',
    :client_ca_cert   => 'files/ca/client_ca.crt',
    :dh_params        => 'files/ca/dh.pem',
    :commercial_key   => 'files/cert/#{arg}.key',
    :commercial_csr   => 'files/cert/#{arg}.csr',
    :commercial_cert  => 'files/cert/#{arg}.crt',
    :commercial_ca_cert  => 'files/cert/commercial_ca.crt',
    :vagrantfile         => 'test/Vagrantfile',

    # node output files
    :hiera            => 'hiera/#{arg}.yaml',
    :node_ssh_pub_key => 'files/nodes/#{arg}/#{arg}_ssh.pub',
    :node_x509_key    => 'files/nodes/#{arg}/#{arg}.key',
    :node_x509_cert   => 'files/nodes/#{arg}/#{arg}.crt',

    # testing files
    :test_client_key     => 'test/cert/client.key',
    :test_client_cert    => 'test/cert/client.crt',
    :test_openvpn_config => 'test/openvpn/#{arg}.ovpn',
    :test_client_openvpn_template => 'test/openvpn/client.ovpn.erb'
  }

  #
  # paths that take node name as the argument
  #
  NODE_PATHS = [
    :node_config, :hiera, :node_x509_cert, :node_x509_key, :node_ssh_pub_key
  ]

  def self.platform
    @platform
  end

  def self.provider_base
    "#{platform}/provider_base"
  end

  def self.provider_templates
    "#{platform}/provider_templates"
  end

  def self.provider
    @provider
  end

  def self.set_provider_path(provider)
    @provider = provider
  end
  def self.set_platform_path(platform)
    @platform = platform
  end

  #
  # tries to find a file somewhere
  #
  def self.find_file(arg)
    [Path.provider, Path.provider_base].each do |base|
      file_path = named_path(arg, base)
      return file_path if File.exists?(file_path)
      if arg.is_a? String
        file_path = base + '/files/' + arg
        return file_path if File.exists?(file_path)
      end
    end
    return nil
  end

  #
  # Three ways of calling:
  #
  # - named_path [:user_ssh, 'bob']  ==> 'users/bob/bob_ssh.pub'
  # - named_path :known_hosts        ==> 'files/ssh/known_hosts'
  # - named_path '/tmp/x'            ==> '/tmp/x'
  #
  def self.named_path(name, provider_dir=Path.provider)
    if name.is_a? Array
      if name.length > 2
        arg = name[1..-1]
        name = name[0]
      else
        name, arg = name
      end
    else
      arg = nil
    end

    if name.is_a? Symbol
      Util::assert!(NAMED_PATHS[name], "Error, I don't know the path for :#{name} (with argument '#{arg}')")
      filename = eval('"' + NAMED_PATHS[name] + '"')
      return provider_dir + '/' + filename
    else
      return name
    end
  end

  def self.exists?(name, provider_dir=nil)
    File.exists?(named_path(name, provider_dir))
  end

  def self.relative_path(path, provider_dir=Path.provider)
    if provider_dir
      path = named_path(path, provider_dir)
      path.sub(/^#{Regexp.escape(provider_dir)}\//,'')
    else
      path
    end
  end

end; end
