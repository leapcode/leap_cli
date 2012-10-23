require 'fileutils'

module LeapCli; module Path

  NAMED_PATHS = {
    # directories
    :hiera_dir        => 'hiera',
    :files_dir        => 'files',
    :nodes_dir        => 'nodes',
    :services_dir     => 'services',
    :tags_dir         => 'tags',

    # input config files
    :common_config    => 'common.json',
    :provider_config  => 'provider.json',
    :node_config      => 'nodes/#{arg}.json',
    :service_config   => 'services/#{arg}.json',
    :tag_config       => 'tags/#{arg}.json',

    # output files
    :user_ssh         => 'users/#{arg}/#{arg}_ssh.pub',
    :user_pgp         => 'users/#{arg}/#{arg}_pgp.pub',
    :hiera            => 'hiera/#{arg}.yaml',
    :node_ssh_pub_key => 'files/nodes/#{arg}/#{arg}_ssh_key.pub',
    :known_hosts      => 'files/ssh/known_hosts',
    :authorized_keys  => 'files/ssh/authorized_keys'
  }

  #
  # required file structure
  #
  # Option 1 -- A project directory with platform and provider directories
  #
  #  -: $root
  #   :-- leap_platform
  #   '-: provider
  #     '-- provider.json
  #
  #  $root can be any name
  #
  # Option 2 -- A stand alone provider directory
  #
  #  -: $provider
  #   '-- provider.json
  #
  #  $provider can be any name. Some commands are not available.
  #
  # In either case, the 'leap' command must be run from inside the provider directory or
  # you must specify root directory with --root=dir.
  #

  def self.root
    @root ||= File.expand_path("#{provider}/..")
  end

  def self.platform
    @platform ||= File.expand_path("#{root}/leap_platform")
  end

  def self.platform_provider
    "#{platform}/provider"
  end

  def self.provider
    @provider ||= if @root
      File.expand_path("#{root}/provider")
    else
      find_in_directory_tree('provider.json')
    end
  end

  def self.ok?
    provider != '/'
  end

  def self.set_root(root_path)
    @root = File.expand_path(root_path)
    raise "No such directory '#{@root}'" unless File.directory?(@root)
  end

  #
  # all the places we search for a file when using find_file.
  # this is perhaps too many places.
  #
  def self.search_path
    @search_path ||= begin
      search_path = []
      [Path.platform_provider, Path.provider].each do |provider|
        files_dir = named_path(:files_dir, provider)
        search_path << provider
        search_path << named_path(:files_dir, provider)
        search_path << named_path(:nodes_dir, files_dir)
        search_path << named_path(:services_dir, files_dir)
        search_path << named_path(:tags_dir, files_dir)
      end
      search_path
    end
  end

  #
  # tries to find a file somewhere with 'filename', under a directory 'name' if possible.
  #
  def self.find_file(name, filename)
    # named path?
    if filename.is_a? Symbol
      path = named_path([filename, name], platform_provider)
      return path if File.exists?(path)
      path = named_path([filename, name], provider)
      return path if File.exists?(path)
    end

    # otherwise, lets search
    search_path.each do |path_root|
      path = [path_root, name, filename].join('/')
      return path if File.exists?(path)
    end
    search_path.each do |path_root|
      path = [path_root, filename].join('/')
      return path if File.exists?(path)
    end

    # give up
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
      name, arg = name
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

  private

  def self.find_in_directory_tree(filename)
    search_dir = Dir.pwd
    while search_dir != "/"
      Dir.foreach(search_dir) do |f|
        return search_dir if f == filename
      end
      search_dir = File.dirname(search_dir)
    end
    return search_dir
  end

end; end
