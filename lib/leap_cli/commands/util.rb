module LeapCli; module Commands

  extend self
  extend LeapCli::Util

  def path(name)
    Path.named_path(name)
  end

  #
  # keeps prompting the user for a numbered choice, until they pick a good one or bail out.
  #
  # block is yielded and is responsible for rendering the choices.
  #
  def numbered_choice_menu(msg, items, &block)
    while true
      say("\n" + msg + ':')
      items.each_with_index &block
      say("q.  quit")
      index = ask("number 1-#{items.length}> ")
      if index.empty?
        next
      elsif index =~ /q/
        bail!
      else
        i = index.to_i - 1
        if i < 0 || i >= items.length
          bail!
        else
          return i
        end
      end
    end
  end

  #
  #
  #
  # FYI
  #  Capistrano::Logger::IMPORTANT = 0
  #  Capistrano::Logger::INFO      = 1
  #  Capistrano::Logger::DEBUG     = 2
  #  Capistrano::Logger::TRACE     = 3
  #
  def ssh_connect(nodes, options={}, &block)
    node_list = parse_node_list(nodes)

    cap = new_capistrano
    cap.logger.level = LeapCli.log_level
    user = options[:user] || 'root'
    cap.set :user, user
    cap.set :ssh_options, ssh_options
    cap.set :use_sudo, false # we may want to change this in the future

    # supply drop options
    cap.set :puppet_source, [Path.platform, 'puppet'].join('/')
    cap.set :puppet_destination, '/root/leap'
    #cap.set :puppet_command, 'puppet apply'
    cap.set :puppet_lib, "puppet/modules"
    cap.set :puppet_parameters, '--confdir=puppet puppet/manifests/site.pp'
    #cap.set :puppet_stream_output, false
    #puppet apply --confdir=puppet puppet/manifests/site.pp  | grep -v 'warning:.*is deprecated'
    #puppet_cmd = "cd #{puppet_destination} && #{sudo_cmd} #{puppet_command} --modulepath=#{puppet_lib} #{puppet_parameters}"

    #
    # allow password authentication when we are bootstraping a single node.
    #
    if options[:bootstrap] && node_list.size == 1
      hostname = node_list.values.first.name
      cap.set(:password) { ask("SSH password for #{user}@#{hostname}> ") } # only called if needed
      # this can be used instead to hide echo -- Capistrano::CLI.password_prompt
    end

    node_list.each do |name, node|
      cap.server node.name, :dummy_arg, node_options(node)
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
      :user_known_hosts_file => path(:known_hosts),
      :paranoid => true
    }
  end

  #
  # For notes on advanced ways to set server-specific options, see
  # http://railsware.com/blog/2011/11/02/advanced-server-definitions-in-capistrano/
  #
  def node_options(node)
    password_proc = Proc.new {Capistrano::CLI.password_prompt "Root SSH password for #{node.name}"}  # only called if needed
    {
      :password => password_proc,
      :ssh_options => {
        :host_key_alias => node.name,
        :host_name => node.ip_address,
        :port => node.ssh.port
      }
    }
  end

  def new_capistrano
    # load once the library files
    @capistrano_enabled ||= begin
      require 'capistrano'
      #require 'capistrano/cli'
      require 'leap_cli/remote/plugin'
      Capistrano.plugin :leap, LeapCli::Remote::Plugin
      true
    end

    # create capistrano instance
    cap = Capistrano::Configuration.new

    # add tasks to capistrano instance
    cap.load File.dirname(__FILE__) + '/../remote/tasks.rb'

    return cap
  end

  def parse_node_list(nodes)
    if nodes.is_a? Config::Object
      Config::ObjectList.new(node_list)
    elsif nodes.is_a? Config::ObjectList
      nodes
    elsif nodes.is_a? String
      manager.filter!(nodes)
    else
      bail! "argument error"
    end
  end

end; end
