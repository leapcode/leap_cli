module LeapCli
  module Commands

    desc 'Compile json files to hiera configs'
    command :compile do |c|
      c.action do |global_options,options,args|
        manager.load(Path.provider)
        Path.ensure_dir(Path.hiera)
        manager.export(Path.hiera)
      end
    end

  end
end