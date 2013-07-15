#
# these methods are made available in capistrano tasks as 'rsync.method_name'
# (see RemoteCommand::new_capistrano)
#

require 'rsync_command'

module LeapCli; module Remote; module RsyncPlugin

  #
  # takes a block, yielded a server, that should return a hash with various rsync options.
  # supported options include:
  #
  #   {:source => '', :dest => '', :flags => '', :includes => [], :excludes => []}
  #
  def update
    rsync = RsyncCommand.new(:logger => logger)
    rsync.asynchronously(find_servers) do |server|
      options = yield server
      next unless options
      remote_user = server.user || fetch(:user, ENV['USER'])
      src = options[:source]
      dest = {:user => remote_user, :host => server.host, :path => options[:dest]}
      options[:ssh] = ssh_options.merge(server.options[:ssh_options]||{})
      options[:chdir] ||= Path.provider
      rsync.exec(src, dest, options)
    end
    if rsync.failed?
      LeapCli::Util.bail! do
        LeapCli::Util.log :failed, "to rsync to #{rsync.failures.map{|f|f[:dest][:host]}.join(' ')}"
      end
    end
  end

end; end; end
