module LeapCli
  module Commands

    desc 'Apply recipes to a node or set of nodes'
    long_desc 'The node filter can be the name of a node, service, or tag.'
    arg_name '<node filter>'
    command :deploy do |c|
      c.action do |global_options,options,args|
        init_submodules

        nodes = manager.filter!(args)
        if nodes.size > 1
          say "Deploying to these nodes: #{nodes.keys.join(', ')}"
          unless agree "Continue? "
            quit! "OK. Bye."
          end
        end

        ssh_connect(nodes) do |ssh|
          # directory setup
          ssh.leap.mkdir("/etc/leap")
          ssh.leap.mkdir("/srv/leap")
          ssh.leap.chown_root("/etc/leap")
          ssh.leap.chown_root("/srv/leap")

          # sync hiera conf
          ssh.leap.log :updating, "hiera.yaml" do
            ssh.leap.rsync_update do |server|
              node = manager.node(server.host)
              {:source => Path.named_path([:hiera, node.name]), :dest => "/etc/leap/hiera.yaml"}
            end
          end

          # sync puppet
          #
          # what we want:
          #     puppet apply --confdir /srv/leap/puppet /srv/leap/puppet/manifests/site.pp | grep -v 'warning:.*is deprecated'
          #
          # what we get currently:
          #
          #
          ssh.set :puppet_source, [Path.platform, 'puppet'].join('/')
          ssh.set :puppet_destination, '/srv/leap'
          ssh.set :puppet_command, '/usr/bin/puppet apply --color=false'
          ssh.set :puppet_lib, "puppet/modules"
          ssh.set :puppet_parameters, '--confdir puppet puppet/manifests/site.pp'
          ssh.set :puppet_stream_output, true
          ssh.apply_puppet
        end
      end
    end

    private

    def init_submodules
      Dir.chdir Path.platform do
        statuses = assert_run! "git submodule status"
        statuses.strip.split("\n").each do |status_line|
          if status_line =~ /^-/
            submodule = status_line.split(' ')[1]
            log "Updating submodule #{submodule}"
            assert_run! "git submodule update --init #{submodule}"
          end
        end
      end
    end

  end
end