
module LeapCli
  module Commands

    desc 'Compile json files to hiera configs'
    command :compile do |c|
      c.action do |global_options,options,args|
        update_compiled_ssh_configs                     # this must come first, hiera configs import these files.
        manager.export Path.named_path(:hiera_dir)      # generate a hiera .yaml config for each node
      end
    end

    def update_compiled_ssh_configs
      update_authorized_keys
      update_known_hosts
    end

  end
end