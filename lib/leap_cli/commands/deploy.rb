module LeapCli
  module Commands

    desc 'Apply recipes to a node or set of nodes'
    long_desc 'The node filter can be the name of a node, service, or tag.'
    arg_name '<node filter>'
    command :deploy do |c|
      c.action do |global_options,options,args|
        nodes = manager.filter!(args)
        if nodes.size > 1
          say "Deploying to these nodes: #{nodes.keys.join(', ')}"
          unless agree "Continue? "
            quit! "OK. Bye."
          end
        end
        leap_root = '/root/leap'
        ssh_connect(nodes) do |ssh|
          ssh.leap.mkdir_leap leap_root
          ssh.leap.rsync_update do |server|
            node = manager.node(server.host)
            {:source => Path.named_path([:hiera, node.name]), :dest => "#{leap_root}/config/#{node.name}.yaml"}
          end
          ssh.apply_puppet
        end
      end
    end

  end
end