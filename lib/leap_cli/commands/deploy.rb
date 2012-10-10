module LeapCli
  module Commands

    desc 'Apply recipes to a node or set of nodes'
    long_desc 'The node filter can be the name of a node, service, or tag.'
    arg_name '<node filter>'
    command :deploy do |c|
      c.action do |global_options,options,args|
        nodes = manager.filter(args)
        say "Deploying to these nodes: #{nodes.keys.join(', ')}"
        if agree "Continue? "
          say "deploy not yet implemented"
        else
          say "OK. Bye."
        end
      end
    end

  end
end