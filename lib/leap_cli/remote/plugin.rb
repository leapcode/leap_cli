#
# these methods are made available in capistrano tasks as 'leap.method_name'
#

module LeapCli; module Remote; module Plugin

  def mkdir(dir)
    run "mkdir -p #{dir}"
  end

  def chown_root(dir)
    run "chown root -R #{dir} && chmod -R ag-rwx,u+rwX #{dir}"
  end

  #
  # takes a block, yielded a server, that should return {:source => '', :dest => ''}
  #
  def rsync_update
    SupplyDrop::Util.thread_pool_size = puppet_parallel_rsync_pool_size
    servers = SupplyDrop::Util.optionally_async(find_servers, puppet_parallel_rsync)

    # rsync to each server
    failed_servers = servers.map do |server|

      # build rsync command
      paths       = yield server
      remote_user = server.user || fetch(:user, ENV['USER'])
      rsync_cmd = SupplyDrop::Rsync.command(
        paths[:source],
        SupplyDrop::Rsync.remote_address(remote_user, server.host, paths[:dest]),
        {:ssh => ssh_options.merge(server.options[:ssh_options]||{})}
      )

      # run command
      logger.debug rsync_cmd
      server.host unless system rsync_cmd

    end.compact

    raise "rsync failed on #{failed_servers.join(',')}" if failed_servers.any?
  end

end; end; end