require 'md5'

module LeapCli

  class FileMissing < Exception
    attr_reader :file_path
    def initialize(file_path)
      @file_path = file_path
    end
  end

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
      #say("ERROR: " + message)
    end

    #
    # quit with a message that we are bailing out.
    #
    def bail!(message="")
      say(message)
      say("Bailing out.")
      raise SystemExit.new
      #ENV['GLI_DEBUG'] = "false"
      #exit_now!(message)
    end

    #
    # quit with no message
    #
    def quit!(message='')
      say(message)
      raise SystemExit.new
    end

    #
    # bails out with message if assertion is false.
    #
    def assert!(boolean, message)
      bail!(message) unless boolean
    end

    #
    # assert that the command is available
    #
    def assert_bin!(cmd_name)
      assert! `which #{cmd_name}`.strip.any?, "Sorry, bailing out, the command '%s' is not installed." % cmd_name
    end

    #
    # assert that the command is run without an error.
    # if successful, return output.
    #
    def assert_run!(cmd, message)
      log2(" * run: #{cmd}")
      cmd = cmd + " 2>&1"
      output = `#{cmd}`
      assert!($?.success?, message)
      return output
    end

    ##
    ## FILES AND DIRECTORIES
    ##

    def relative_path(path)
      path.sub(/^#{Regexp.escape(Path.provider)}\//,'')
    end

    def progress_created(path)
      progress 'created %s' % relative_path(path)
    end

    def progress_updated(path)
      progress 'updated %s' % relative_path(path)
    end

    def progress_nochange(path)
      progress2 'no change %s' % relative_path(path)
    end

    def progress_removed(path)
      progress 'removed %s' % relative_path(path)
    end

    #
    # creates a directory if it doesn't already exist
    #
    def ensure_dir(dir)
      unless File.directory?(dir)
        if File.exists?(dir)
          bail! 'Unable to create directory "%s", file already exists.' % dir
        else
          FileUtils.mkdir_p(dir)
          unless dir =~ /\/$/
            dir = dir + '/'
          end
          progress_created dir
        end
      end
    end

    NAMED_PATHS = {
      :user_ssh => 'users/#{arg}/#{arg}_ssh.pub',
      :user_pgp => 'users/#{arg}/#{arg}_pgp.pub',
      :hiera => 'hiera/#{arg}.yaml',
      :node_ssh_pub_key => 'files/nodes/#{arg}/#{arg}_ssh_key.pub',
      :known_hosts => 'files/ssh/known_hosts',
      :authorized_keys => 'files/ssh/authorized_keys'
    }

    def read_file!(*args)
      begin
        try_to_read_file!(*args)
      rescue FileMissing => exc
        bail!("File '%s' does not exist." % exc.file_path)
      end
    end

    def read_file(*args)
      begin
        try_to_read_file!(*args)
      rescue FileMissing => exc
        return nil
      end
    end

    #
    # Three ways to call:
    #
    # - write_file!(file_path, file_contents)
    # - write_file!(named_path, file_contents)
    # - write_file!(named_path, file_contents, argument)  -- deprecated
    # - write_file!([named_path, argument], file_contents)
    #
    #
    def write_file!(*args)
      if args.first.is_a? Symbol
        write_named_file!(*args)
      elsif args.first.is_a? Array
        write_named_file!(args.first[0], args.last, args.first[1])
      else
        write_to_path!(*args)
      end
    end

    def remove_file!(file_path)
      if File.exists?(file_path)
        File.unlink(file_path)
        progress_removed(file_path)
      end
    end

    #
    # saves a named file.
    #
    def write_named_file!(name, contents, arg=nil)
      fullpath = named_path(name, arg)
      write_to_path!(fullpath, contents)
    end

    def named_path(name, arg=nil)
      assert!(NAMED_PATHS[name], "Error, I don't know the path for :#{name} (with argument '#{arg}')")
      filename = eval('"' + NAMED_PATHS[name] + '"')
      fullpath = Path.provider + '/' + filename
    end

    def write_to_path!(filepath, contents)
      ensure_dir File.dirname(filepath)
      existed = File.exists?(filepath)
      if existed
        if file_content_is?(filepath, contents)
          progress_nochange filepath
          return
        end
      end

      File.open(filepath, 'w') do |f|
        f.write contents
      end

      if existed
        progress_updated filepath
      else
        progress_created filepath
      end
    end

    private

    def file_content_is?(filepath, contents)
      output = `md5sum '#{filepath}'`.strip
      if $?.to_i == 0
        return output.split(" ").first == MD5.md5(contents).to_s
      else
        return false
      end
    end

    #
    # trys to read a file, raise exception if the file doesn't exist.
    #
    def try_to_read_file!(*args)
      if args.first.is_a? Symbol
        file_path = named_path(args.first)
      elsif args.first.is_a? Array
        file_path = named_path(*args.first)
      else
        file_path = args.first
      end
      if !File.exists?(file_path)
        raise FileMissing.new(file_path)
      else
        File.read(file_path)
      end
    end

  end
end

