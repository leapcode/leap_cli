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
    cap.logger = LeapCli::Logger.new(:level => LeapCli.log_level)
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
      cap.server node.name, :dummy_arg, node_options(node, options[:ssh_options])
    end

    yield cap
  end

  private

  #
  # For available options, see http://net-ssh.github.com/net-ssh/classes/Net/SSH.html#method-c-start
  #
  def ssh_options
    {
      :config => false,
      :global_known_hosts_file => path(:known_hosts),
      :paranoid => true
    }
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
    ssh_options_override ||= {}
    {
      :ssh_options => {
        :host_key_alias => node.name,
        :host_name => node.ip_address,
        :port => node.ssh.port
      }.merge(contingent_ssh_options_for_node(node)).merge(ssh_options_override)
    }
  end

  def new_capistrano
    # load once the library files
    @capistrano_enabled ||= begin
      require 'capistrano'
      require 'capistrano/cli'
      require 'lib_ext/capistrano_connections'
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
    if node.vagrant?
      {:keys => [vagrant_ssh_key_file]}
    else
      {}
    end
  end

end; end; end