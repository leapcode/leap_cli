module LeapCli; module Util; module RemoteCommand
  extend self

  #
  # FYI
  #  Capistrano::Logger::IMPORTANT = 0
  #  Capistrano::Logger::INFO      = 1
  #  Capistrano::Logger::DEBUG     = 2
  #  Capistrano::Logger::TRACE     = 3
  #
  def ssh_connect(nodes, options={}, &block)
    options ||= {}
    node_list = parse_node_list(nodes)

    cap = new_capistrano
    cap.logger = LeapCli::Logger.new(:level => [LeapCli.logger.log_level,3].min)
    user = options[:user] || 'root'
    cap.set :user, user
    cap.set :ssh_options, ssh_options # ssh options common to all nodes
    cap.set :use_sudo, false          # we may want to change this in the future

    # Allow password authentication when we are bootstraping a single node
    # (and key authentication fails).
    if options[:bootstrap] && node_list.size == 1
      hostname = node_list.values.first.name
      if options[:echo]
        cap.set(:password) { ask "Root SSH password for #{user}@#{hostname}> " }
      else
        cap.set(:password) { Capistrano::CLI.password_prompt " * Typed password will be hidden (use --echo to make it visible)\nRoot SSH password for #{user}@#{hostname}> " }
      end
    end

    node_list.each do |name, node|
      cap.server node.domain.full, :dummy_arg, node_options(node, options[:ssh_options])
    end

    yield cap
  rescue Capistrano::ConnectionError => exc
    # not sure if this will work if english is not the locale??
    if exc.message =~ /Too many authentication failures/
      at_exit {ssh_config_help_message}
    end
    raise exc
  end

  private

  #
  # For available options, see http://net-ssh.github.com/net-ssh/classes/Net/SSH.html#method-c-start
  #
  # Capistrano has some very evil behavior in it's ssh.rb:
  #
  #   ssh_options = Net::SSH.configuration_for(
  #     server.host, ssh_options.fetch(:config, true)
  #   ).merge(ssh_options)
  #   # Once we've loaded the config, we don't need Net::SSH to do it again.
  #   ssh_options[:config] = false
  #
  # Net:SSH is supposed to call Net::SSH.configuration_for, but Capistrano is doing it
  # in advance and then disabling loading of configs.
  #
  # The result of this is the following: if you have IdentityFile in your ~/.ssh/config
  # file, then the above code will transform the ssh_options by reading ~/.ssh/config
  # and adding the keys specified via IdentityFile to ssh_options...
  # AND IT WILL SET :keys_only TO TRUE.
  #
  # The problem is that :keys_only will disable Net:SSH's ability to use ssh-agent.
  # With :keys_only set to true, it will not consult the ssh-agent at all.
  #
  # So nice of capistrano to parse ~/.ssh/config for us, but then add flags to the
  # ssh_options that prevent's these options from being useful.
  #
  # The current hackaround is to force :keys_only to be false. This allows the config
  # to be read and also allows ssh-agent to still be used.
  #
  def ssh_options
    {
      :keys_only => false, # Don't you dare change this.
      :global_known_hosts_file => path(:known_hosts),
      :user_known_hosts_file => '/dev/null',
      :paranoid => true,
      :verbose => net_ssh_log_level
    }
  end

  def net_ssh_log_level
    if DEBUG
      case LeapCli.logger.log_level
        when 1 then 3
        when 2 then 2
        when 3 then 1
        else 0
      end
    else
      nil
    end
  end

  #
  # For notes on advanced ways to set server-specific options, see
  # http://railsware.com/blog/2011/11/02/advanced-server-definitions-in-capistrano/
  #
  # if, in the future, we want to do per-node password options, it would be done like so:
  #
  #  password_proc = Proc.new {Capistrano::CLI.password_prompt "Root SSH password for #{node.name}"}
  #  return {:password => password_proc}
  #
  def node_options(node, ssh_options_override=nil)
    {
      :ssh_options => {
        # :host_key_alias => node.name, << incompatible with ports in known_hosts
        :host_name => node.ip_address,
        :port => node.ssh.port
      }.merge(contingent_ssh_options_for_node(node)).merge(ssh_options_override||{})
    }
  end

  def new_capistrano
    # load once the library files
    @capistrano_enabled ||= begin
      require 'capistrano'
      require 'capistrano/cli'
      require 'leap_cli/lib_ext/capistrano_connections'
      require 'leap_cli/remote/leap_plugin'
      require 'leap_cli/remote/puppet_plugin'
      require 'leap_cli/remote/rsync_plugin'
      Capistrano.plugin :leap, LeapCli::Remote::LeapPlugin
      Capistrano.plugin :puppet, LeapCli::Remote::PuppetPlugin
      Capistrano.plugin :rsync, LeapCli::Remote::RsyncPlugin
      true
    end

    # create capistrano instance
    cap = Capistrano::Configuration.new

    # add tasks to capistrano instance
    cap.load File.dirname(__FILE__) + '/../remote/tasks.rb'

    return cap
  end

  def contingent_ssh_options_for_node(node)
    opts = {}
    if node.vagrant?
      opts[:keys] = [vagrant_ssh_key_file]
      opts[:keys_only] = true # only use the keys specified above, and ignore whatever keys the ssh-agent is aware of.
      opts[:paranoid] = false # we skip host checking for vagrant nodes, because fingerprint is different for everyone.
      if LeapCli.logger.log_level <= 1
        opts[:verbose] = :error # suppress all the warnings about adding host keys to known_hosts, since it is not actually doing that.
      end
    end
    if !node.supported_ssh_host_key_algorithms.empty?
      opts[:host_key] = node.supported_ssh_host_key_algorithms
    end
    return opts
  end

end; end; end