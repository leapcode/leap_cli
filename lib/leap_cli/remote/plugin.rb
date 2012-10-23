#
# these methods are made available in capistrano tasks as 'leap.method_name'
#

module LeapCli; module Remote; module Plugin

  def mkdir_leap(base_dir)
    run "mkdir -p #{base_dir}/config && chown -R root #{base_dir} && chmod -R ag-rwx,u+rwX #{base_dir}"
  end

  #
  # takes a block, yielded a server, that should return {:source => '', :dest => ''}
  #
  def rsync_update
    SupplyDrop::Util.thread_pool_size = puppet_parallel_rsync_pool_size
    servers = SupplyDrop::Util.optionally_async(find_servers, puppet_parallel_rsync)
    failed_servers = servers.map do |server|
      #p server
      #p server.options
      # build rsync command
      _paths     = yield server
      _source    = _paths[:source]
      _user      = server.user || fetch(:user, ENV['USER'])
      _dest      = SupplyDrop::Rsync.remote_address(_user, server.host, _paths[:dest])
      _opts      = {:ssh => ssh_options.merge(server.options[:ssh_options]||{})}
      rsync_cmd = SupplyDrop::Rsync.command(_source, _dest, _opts)

      # run command
      logger.debug rsync_cmd
      server.host unless system rsync_cmd
    end.compact
    raise "rsync failed on #{failed_servers.join(',')}" if failed_servers.any?
  end

end; end; end