require 'digest/md5'
require 'fileutils'
require 'pathname'
require 'erb'
require 'pty'

module LeapCli
  module Util
    extend self

    @@exit_status = nil

    def log(*args, &block)
      LeapCli.log(*args, &block)
    end

    ##
    ## QUITTING
    ##

    def exit_status(code=nil)
      if !code.nil?
        if code == 0 && @@exit_status.nil?
          @@exit_status = 0
        else
          @@exit_status = code
        end
      end
      @@exit_status
    end

    #
    # quit and print help
    #
    def help!(message=nil)
      ENV['GLI_DEBUG'] = "false"
      help_now!(message)
    end

    #
    # exit with error code and with a message that we are bailing out.
    #
    def bail!(*message, &block)
      LeapCli.logger.log_level = 3 if LeapCli.logger.log_level < 3
      if message.any?
        log(0, *message, &block)
      else
        log(0, :bailing, "out", &block)
      end
      raise SystemExit.new(exit_status || 1)
    end

    #
    # quit with message, but no additional error or warning about bailing.
    #
    def quit!(message='')
      puts(message)
      raise SystemExit.new(exit_status || 0)
    end

    #
    # bails out with message if assertion is false.
    #
    def assert!(boolean, message=nil, &block)
      if !boolean
        bail!(message, &block)
      end
    end

    #
    # assert that the command is available
    #
    def assert_bin!(cmd_name, msg=nil)
      assert! `which #{cmd_name}`.strip.any? do
        log :missing, "command '%s'" % cmd_name do
          if msg
            log msg
          end
        end
      end
    end

    #
    # assert that the command is run without an error.
    # if successful, return output.
    #
    def assert_run!(cmd, message=nil)
      cmd = cmd + " 2>&1"
      output = `#{cmd}`.strip
      unless $?.success?
        exit_status($?.exitstatus)
        bail! do
          log :run, cmd
          log :failed, "(exit #{$?.exitstatus}) #{output}", :indent => 1
          log message, :indent => 1 if message
        end
      else
        log 2, :ran, cmd
      end
      return output
    end

    def assert_config!(conf_path)
      value = nil
      begin
        value = manager.instance_eval(conf_path)
      #rescue NoMethodError
      #rescue NameError
      ensure
        assert! !value.nil? && value != "REQUIRED" do
          log :missing, "required configuration value for #{conf_path}"
        end
      end
    end

    ##
    ## FILES AND DIRECTORIES
    ##

    def assert_files_missing!(*files)
      options = files.last.is_a?(Hash) ? files.pop : {}
      base = options[:base] || Path.provider
      file_list = files.collect { |file_path|
        file_path = Path.named_path(file_path, base)
        File.exist?(file_path) ? Path.relative_path(file_path, base) : nil
      }.compact
      if file_list.length > 1
        bail! do
          log :error, "Sorry, we can't continue because these files already exist: #{file_list.join(', ')}."
          log options[:msg] if options[:msg]
        end
      elsif file_list.length == 1
        bail! do
          log :error, "Sorry, we can't continue because this file already exists: #{file_list.first}."
          log options[:msg] if options[:msg]
        end
      end
    end

    def assert_files_exist!(*files)
      options = files.last.is_a?(Hash) ? files.pop : {}
      file_list = files.collect { |file_path|
        file_path = Path.named_path(file_path)
        !File.exist?(file_path) ? Path.relative_path(file_path) : nil
      }.compact
      if file_list.length > 1
        bail! do
          log :missing, "these files: #{file_list.join(', ')}"
          log options[:msg] if options[:msg]
        end
      elsif file_list.length == 1
        bail! do
          log :missing, "file #{file_list.first}"
          log options[:msg] if options[:msg]
        end
      end
    end

    # takes a list of symbolic paths. returns true if all files exist or are directories.
    def file_exists?(*files)
      files.each do |file_path|
        file_path = Path.named_path(file_path)
        if !File.exist?(file_path)
          return false
        end
      end
      return true
    end

    # takes a list of symbolic paths. returns true if all are directories.
    def dir_exists?(*dirs)
      dirs.each do |dir_path|
        dir_path = Path.named_path(dir_path)
        if !Dir.exists?(dir_path)
          return false
        end
      end
      return true
    end

    #
    # creates a directory if it doesn't already exist
    #
    def ensure_dir(dir)
      dir = Path.named_path(dir)
      unless File.directory?(dir)
        assert_files_missing!(dir, :msg => "Cannot create directory #{dir}")
        FileUtils.mkdir_p(dir, :mode => 0700)
        unless dir =~ /\/$/
          dir = dir + '/'
        end
        log :created, dir
      end
    end

    ##
    ## FILE READING, WRITING, DELETING, and MOVING
    ##

    #
    # All file read and write methods support using named paths in the place of an actual file path.
    #
    # To call using a named path, use a symbol in the place of filepath, like so:
    #
    #   read_file(:known_hosts)
    #
    # In some cases, the named path will take an argument. In this case, set the filepath to be an array:
    #
    #   write_file!([:user_ssh, 'bob'], ssh_key_str)
    #
    # To resolve a named path, use the shortcut helper 'path()'
    #
    #   path([:user_ssh, 'bob'])  ==>   files/users/bob/bob_ssh_pub.key
    #

    def read_file!(filepath)
      filepath = Path.named_path(filepath)
      assert_files_exist!(filepath)
      File.read(filepath, :encoding => 'UTF-8')
    end

    def read_file(filepath)
      filepath = Path.named_path(filepath)
      if file_exists?(filepath)
        File.read(filepath, :encoding => 'UTF-8')
      end
    end

    #
    # replace contents of a file, with an exclusive lock.
    #
    # 1. locks file
    # 2. reads contents
    # 3. yields contents
    # 4. replaces file with return value of the block
    #
    def replace_file!(filepath, &block)
      filepath = Path.named_path(filepath)
      if !File.exist?(filepath)
        content = yield(nil)
        unless content.nil?
          write_file!(filepath, content)
        end
      else
        File.open(filepath, File::RDWR|File::CREAT, 0600, :encoding => 'UTF-8') do |f|
          f.flock(File::LOCK_EX)
          old_content = f.read
          new_content = yield(old_content)
          if old_content == new_content
            log :nochange, filepath, 2
          else
            f.rewind
            f.write(new_content)
            f.flush
            f.truncate(f.pos)
            log :updated, filepath
          end
        end
      end
    end

    def remove_file!(filepath)
      filepath = Path.named_path(filepath)
      if File.exist?(filepath)
        if File.directory?(filepath)
          remove_directory!(filepath)
        else
          begin
            File.unlink(filepath)
            log :removed, filepath
          rescue Exception => exc
            bail! do
              log :failed, "to remove file #{filepath}"
              log "error message: " + exc.to_s
            end
          end
        end
      end
    end

    def remove_directory!(filepath)
      filepath = Path.named_path(filepath)
      if filepath !~ /^#{Regexp.escape(Path.provider)}/ || filepath =~ /\.\./
        bail! "sanity check on rm -r did not pass for #{filepath}"
      end
      if File.directory?(filepath)
        begin
          FileUtils.rm_r(filepath)
          log :removed, filepath
        rescue Exception => exc
          bail! do
            log :failed, "to remove directory #{filepath}"
            log "error message: " + exc.to_s
          end
        end
      else
        log :failed, "to remove '#{filepath}', it is not a directory"
      end
    end

    def write_file!(filepath, contents)
      filepath = Path.named_path(filepath)
      ensure_dir File.dirname(filepath)
      existed = File.exist?(filepath)
      if existed
        if file_content_equals?(filepath, contents)
          log :nochange, filepath, 2
          return
        end
      end

      File.open(filepath, 'w', 0600, :encoding => 'UTF-8') do |f|
        f.write contents
      end

      if existed
        log :updated, filepath
      else
        log :created, filepath
      end
    end

    def rename_file!(oldpath, newpath)
      oldpath = Path.named_path(oldpath)
      newpath = Path.named_path(newpath)
      if File.exist? newpath
        log :skipping, "#{Path.relative_path(newpath)}, file already exists"
        return
      end
      if !File.exist? oldpath
        log :skipping, "#{Path.relative_path(oldpath)}, file is missing"
        return
      end
      FileUtils.mv oldpath, newpath
      log :moved, "#{Path.relative_path(oldpath)} to #{Path.relative_path(newpath)}"
    end

    def cmd_exists?(cmd)
      `which #{cmd}`.strip.chars.any?
    end

    #
    # creates a relative symlink from absolute paths, removing prior symlink if necessary
    #
    # symlink 'new' is created, pointing to 'old'
    #
    def relative_symlink(old, new)
      relative_path  = Pathname.new(old).relative_path_from(Pathname.new(new))
      if File.symlink?(new)
        if File.readlink(new) != relative_path.to_s
          File.unlink(new)
          log :updated, 'symlink %s' % Path.relative_path(new)
        end
      else
        log :created, 'symlink %s' % Path.relative_path(new)
      end
      FileUtils.ln_s(relative_path, new)
    end

    #
    # compares md5 fingerprints to see if the contents of a file match the
    # string we have in memory
    #
    def file_content_equals?(filepath, contents)
      filepath = Path.named_path(filepath)
      Digest::MD5.file(filepath).hexdigest == Digest::MD5.hexdigest(contents)
    end

    ##
    ## PROCESSES
    ##

    #
    # run a long running block of code in a separate process and display marching ants as time goes by.
    # if the user hits ctrl-c, the program exits.
    #
    def long_running(&block)
      pid = fork
      if pid == nil
        yield
        exit!
      end
      Signal.trap("SIGINT") do
        Process.kill("KILL", pid)
        Process.wait(pid)
        bail!
      end
      while true
        sleep 0.2
        STDOUT.print '.'
        STDOUT.flush
        break if Process.wait(pid, Process::WNOHANG)
      end
      STDOUT.puts
    end

    #
    # runs a command in a pseudo terminal
    #
    def pty_run(cmd)
      PTY.spawn(cmd) do |output, input, pid|
        begin
          while line = output.gets do
            puts line
          end
        rescue Errno::EIO
        end
      end
    rescue PTY::ChildExited
    end

    ##
    ## ERB
    ##

    def erb_eval(string, binding=nil)
      ERB.new(string, nil, '%<>-').result(binding)
    end

    ##
    ## GIT
    ##

    def is_git_directory?(dir)
      Dir.chdir(dir) do
        `which git && git rev-parse 2>/dev/null`
        return $? == 0
      end
    end
    
    def is_git_subrepo?(dir)
        Dir.chdir(dir) do
          `ls .gitrepo 2>/dev/null`
          return $? == 0
        end
      end



    def current_git_branch(dir)
      Dir.chdir(dir) do
        branch = `git symbolic-ref HEAD 2>/dev/null`.strip
        if branch.chars.any?
          branch.sub(/^refs\/heads\//, '')
        else
          nil
        end
      end
    end

    def current_git_commit(dir)
      Dir.chdir(dir) do
        `git rev-parse HEAD 2>/dev/null`.strip
      end
    end

  end
end

