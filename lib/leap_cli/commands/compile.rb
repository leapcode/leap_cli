
module LeapCli
  module Commands

    desc 'Compiles node configuration files into hiera files used for deployment'
    command :compile do |c|
      c.action do |global_options,options,args|
        compile_hiera_files
      end
    end

    def compile_hiera_files(nodes=nil)
      # these must come first
      update_compiled_ssh_configs

      # export generated files
      manager.export_nodes(nodes)
      manager.export_secrets
    end

    def update_compiled_ssh_configs
      update_authorized_keys
      update_known_hosts
    end

  end
end