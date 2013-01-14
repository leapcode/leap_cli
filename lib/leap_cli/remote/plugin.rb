#
# these methods are made available in capistrano tasks as 'leap.method_name'
#

module LeapCli; module Remote; module Plugin

  def required_packages
    "puppet ruby-hiera-puppet rsync lsb-release"
  end

  def log(*args, &block)
    LeapCli::Util::log(*args, &block)
  end

  #
  # creates directories that are owned by root and 700 permissions
  #
  def mkdirs(*dirs)
    raise ArgumentError.new('illegal dir name') if dirs.grep(/[\' ]/).any?
    run dirs.collect{|dir| "mkdir -m 700 -p #{dir}; "}.join
  end

  def assert_initialized

    begin
      test_initialized_file = "test -f /srv/leap/initialized"
      check_required_packages = "! dpkg-query -W --showformat='${Status}\n' #{required_packages} 2>&1 | grep -q -E '(deinstall|no packages)'"
      run "#{test_initialized_file} && #{check_required_packages}"
    rescue Capistrano::CommandError => exc
      LeapCli::Util.bail! do
        exc.hosts.each do |host|
          LeapCli::Util.log :error, "running deploy: node not initialized. Run 'leap node init #{host}'", :host => host
        end
      end
    end
  end

  def mark_initialized
    run "touch /srv/leap/initialized"
  end

  #def mkdir(dir)
  #  run "mkdir -p #{dir}"
  #end

  #def chown_root(dir)
  #  run "chown root -R #{dir} && chmod -R ag-rwx,u+rwX #{dir}"
  #end

  #
  # takes a block, yielded a server, that should return {:source => '', :dest => ''}
  #
  def rsync_update
    SupplyDrop::Util.thread_pool_size = puppet_parallel_rsync_pool_size
    servers = SupplyDrop::Util.optionally_async(find_servers, puppet_parallel_rsync)

    # rsync to each server
    failed_servers = []
    servers.each do |server|
      options = yield server
      next unless options

      # build rsync command
      remote_user = server.user || fetch(:user, ENV['USER'])
      rsync_options = {
        :flags => options[:flags],
        :includes => options[:includes],
        :excludes => options[:excludes],
        :ssh => ssh_options.merge(server.options[:ssh_options]||{})
      }
      rsync_cmd = SupplyDrop::Rsync.command(
        options[:source],
        SupplyDrop::Rsync.remote_address(remote_user, server.host, options[:dest]),
        rsync_options
      )

      # run command
      logger.debug rsync_cmd
      Dir.chdir(options[:chdir] || '.') do
        ok = system(rsync_cmd)
        failed_servers << server.host unless ok
      end
    end

    raise "rsync failed on #{failed_servers.join(',')}" if failed_servers.any?
  end

  #def logrun(cmd)
  #  @streamer ||= LeapCli::Remote::LogStreamer.new
  #  run cmd do |channel, stream, data|
  #    @streamer.collect_output(channel[:host], data)
  #  end
  #end

#    return_code = nil
#    run "something; echo return code: $?" do |channel, stream, data|
#      if data =~ /return code: (\d+)/
#        return_code = $1.to_i
#      else
#        Capistrano::Configuration.default_io_proc.call(channel, stream, data)
#      end
#    end
#    puts "finished with return code: #{return_code}"

end; end; end