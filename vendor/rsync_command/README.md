RsyncCommand
==================================

The gem rsync_command provides a library wrapper around the rsync command line program, with additional support for parallel execution of rsync and configuration of OpenSSH options in the format understood by Capistrano (and Net::SSH).

Installation
------------------------------------

    gem install rsync_command

Usage
------------------------------------

    rsync   = RsyncCommand.new(:ssh => {:auth_methods => 'publickey'}, :flags => '-a')
    servers = ['red', 'green', 'blue']

    rsync.asynchronously(servers) do |sync, server|
      sync.user = 'root'
      sync.host = server
      sync.source = '/from'
      sync.dest = '/to'
      sync.exec
    end

    if rsync.failed?
      puts rsync.failures.join
    end