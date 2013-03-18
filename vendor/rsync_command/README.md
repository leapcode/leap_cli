RsyncCommand
==================================

The gem rsync_command provides a library wrapper around the rsync command line program, with additional support for parallel execution of rsync and configuration of OpenSSH options in the format understood by Capistrano (and Net::SSH).

Installation
------------------------------------

    gem install rsync_command

Usage
------------------------------------

    rsync   = RsyncCommand.new(:logger => logger, :ssh => {:auth_methods => 'publickey'}, :flags => '-a')
    source  = '/source/path'
    servers = ['red', 'green', 'blue']

    rsync.asynchronously(servers) do |server|
      dest = {:user => 'root', :host => server, :path => '/dest/path'}
      rsync.exec(source, dest)
    end

    if rsync.failed?
      puts rsync.failures.join
    end