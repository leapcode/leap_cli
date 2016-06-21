require 'fileutils'

module LeapCli; module Path

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
  # Tries to find a file somewhere.
  # Path can be a named path or a relative path.
  #
  # relative paths are checked against
  # provider/<path>
  # provider/files/<path>
  # provider_base/<path>
  # provider_base/files/<path>
  #
  #
  def self.find_file(arg)
    [Path.provider, Path.provider_base].each do |base|
      if arg.is_a?(Symbol) || arg.is_a?(Array)
        named_path(arg, base).tap {|path|
          return path if File.exist?(path)
        }
      else
        File.join(base, arg).tap {|path|
          return path if File.exist?(path)
        }
        File.join(base, 'files', arg).tap {|path|
          return path if File.exist?(path)
        }
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
      Util::assert!(Leap::Platform.paths[name], "Error, I don't know the path for :#{name} (with argument '#{arg}')")
      filename = eval('"' + Leap::Platform.paths[name] + '"')
      return provider_dir + '/' + filename
    else
      return name
    end
  end

  def self.exists?(name, provider_dir=nil)
    File.exist?(named_path(name, provider_dir))
  end

  def self.defined?(name)
    Leap::Platform.paths[name]
  end

  def self.relative_path(path, provider_dir=Path.provider)
    if provider_dir
      path = named_path(path, provider_dir)
      path.sub(/^#{Regexp.escape(provider_dir)}\//,'')
    else
      path
    end
  end

  def self.vagrant_ssh_priv_key_file
    File.join(LEAP_CLI_BASE_DIR, 'vendor', 'vagrant_ssh_keys', 'vagrant.key')
  end

  def self.vagrant_ssh_pub_key_file
    File.join(LEAP_CLI_BASE_DIR, 'vendor', 'vagrant_ssh_keys', 'vagrant.pub')
  end

  def self.node_init_script
    File.join(@platform, 'bin', 'node_init')
  end

end; end
