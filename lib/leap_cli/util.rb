require 'digest/md5'
require 'paint'
require 'fileutils'
require 'erb'

module LeapCli

  module Util
    extend self

    ##
    ## QUITTING
    ##

    #
    # quit and print help
    #
    def help!(message=nil)
      ENV['GLI_DEBUG'] = "false"
      help_now!(message)
    end

    #
    # quit with a message that we are bailing out.
    #
    def bail!(message=nil)
      if block_given?
        LeapCli.log_level = 3
        yield
      elsif message
        puts message
      end
      log :bail, ""
      raise SystemExit.new
    end

    #
    # quit with no message
    #
    def quit!(message='')
      puts(message)
      raise SystemExit.new
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
    def assert_bin!(cmd_name)
      assert! `which #{cmd_name}`.strip.any? do
        log :missing, "command '%s'" % cmd_name
      end
    end

    #
    # assert that the command is run without an error.
    # if successful, return output.
    #
    def assert_run!(cmd, message=nil)
      cmd = cmd + " 2>&1"
      output = `#{cmd}`
      unless $?.success?
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

    def assert_files_missing!(*files)
      options = files.last.is_a?(Hash) ? files.pop : {}
      file_list = files.collect { |file_path|
        file_path = Path.named_path(file_path)
        File.exists?(file_path) ? Path.relative_path(file_path) : nil
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

    def assert_config!(conf_path)
      value = nil
      begin
        value = manager.instance_eval(conf_path)
      rescue NoMethodError
      rescue NameError
      end
      assert! !value.nil? && value != "REQUIRED" do
        log :missing, "required configuration value for #{conf_path}"
      end
    end

    def assert_files_exist!(*files)
      options = files.last.is_a?(Hash) ? files.pop : {}
      file_list = files.collect { |file_path|
        file_path = Path.named_path(file_path)
        !File.exists?(file_path) ? Path.relative_path(file_path) : nil
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

    def file_exists?(*files)
      files.each do |file_path|
        file_path = Path.named_path(file_path)
        if !File.exists?(file_path)
          return false
        end
      end
      return true
    end

    ##
    ## FILES AND DIRECTORIES
    ##

    #
    # creates a directory if it doesn't already exist
    #
    def ensure_dir(dir)
      dir = Path.named_path(dir)
      unless File.directory?(dir)
        assert_files_missing!(dir, :msg => "Cannot create directory #{dir}")
        FileUtils.mkdir_p(dir)
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
      File.read(filepath)
    end

    def read_file(filepath)
      filepath = Path.named_path(filepath)
      if file_exists?(filepath)
        File.read(filepath)
      end
    end

    def remove_file!(filepath)
      filepath = Path.named_path(filepath)
      if File.exists?(filepath)
        File.unlink(filepath)
        log :removed, filepath
      end
    end

    def remove_directory!(filepath)
      filepath = Path.named_path(filepath)
      if filepath !~ /^#{Regexp.escape(Path.provider)}/ || filepath =~ /\.\./
        raise "sanity check on rm -r did not pass for #{filepath}"
      end
      if File.directory?(filepath)
        FileUtils.rm_r(filepath)
        log :removed, filepath
      end
    end

    def write_file!(filepath, contents)
      filepath = Path.named_path(filepath)
      ensure_dir File.dirname(filepath)
      existed = File.exists?(filepath)
      if existed
        if file_content_equals?(filepath, contents)
          log :nochange, filepath, 2
          return
        end
      end

      File.open(filepath, 'w') do |f|
        f.write contents
      end

      if existed
        log :updated, filepath
      else
        log :created, filepath
      end
    end

    def cmd_exists?(cmd)
      `which #{cmd}`.strip.chars.any?
    end

    #
    # compares md5 fingerprints to see if the contents of a file match the string we have in memory
    #
    def file_content_equals?(filepath, contents)
      filepath = Path.named_path(filepath)
      output = `md5sum '#{filepath}'`.strip
      if $?.to_i == 0
        return output.split(" ").first == Digest::MD5.hexdigest(contents).to_s
      else
        return false
      end
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

    ##
    ## ERB
    ##

    def erb_eval(string, binding=nil)
      ERB.new(string, nil, '%<>-').result(binding)
    end

  end
end

