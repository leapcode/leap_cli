
module LeapCli
  module Commands

    desc 'Compile json files to hiera configs'
    command :compile do |c|
      c.action do |global_options,options,args|
        manager.load(Path.provider)
        ensure_dir(Path.hiera)
        manager.export(Path.hiera)
        update_authorized_keys
        update_known_hosts
      end
    end

    def update_authorized_keys
      buffer = StringIO.new
      Dir.glob(named_path(:user_ssh, '*')).each do |keyfile|
        buffer << File.read(keyfile)
      end
      write_file!(:authorized_keys, buffer.string)
    end

  end
end