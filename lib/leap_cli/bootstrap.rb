#
# Initial bootstrap loading of all the necessary things that needed
# for the `leap` command.
#

module LeapCli
  module Bootstrap
    extend LeapCli::Log
    extend self

    def setup(argv)
      setup_logging(argv)
      setup_leapfile(argv)
    end

    #
    # print out the version string and exit.
    # called from leap executable.
    #
    def handle_version(app)
      puts "leap #{LeapCli::VERSION}, ruby #{RUBY_VERSION}"
      begin
        log_version
      rescue StandardError => exc
        puts exc.to_s
        raise exc if DEBUG
      end
      exit(0)
    end

    #
    # load the commands.
    # called from leap executable.
    #
    def load_libraries(app)
      if LeapCli.log_level >= 2
        log_version
      end
      load_commands(app)
      load_macros
    end

    #
    # initialize the global options.
    # called from pre.rb
    #
    def setup_global_options(app, global)
      if global[:force]
        global[:yes] = true
      end
      if Process::Sys.getuid == 0
        Util.bail! "`leap` should not be run as root."
      end
    end

    private

    #
    # Initial logging
    #
    # This is called very early by leap executable, because
    # everything depends on the log file and log options
    # being set correctly before any work is done.
    #
    # The Leapfile might later load additional logging
    # options.
    #
    def setup_logging(argv)
      options = parse_logging_options(argv)
      verbose = (options[:verbose] || 1).to_i
      if verbose
        LeapCli.set_log_level(verbose)
      end
      if options[:log]
        LeapCli.log_file = options[:log]
        LeapCli::Util.log_raw(:log) { $0 + ' ' + argv.join(' ')}
      end
      unless options[:color].nil?
        LeapCli.log_in_color = options[:color]
      end
    end

    #
    # load the leapfile and set the Path variables.
    #
    def setup_leapfile(argv)
      LeapCli.leapfile.load
      if LeapCli.leapfile.valid?
        Path.set_platform_path(LeapCli.leapfile.platform_directory_path)
        Path.set_provider_path(LeapCli.leapfile.provider_directory_path)
        if !Path.provider || !File.directory?(Path.provider)
          bail! { log :missing, "provider directory '#{Path.provider}'" }
        end
        if !Path.platform || !File.directory?(Path.platform)
          bail! { log :missing, "platform directory '#{Path.platform}'" }
        end
        if LeapCli.log_file.nil? && LeapCli.leapfile.log
          LeapCli.log_file = LeapCli.leapfile.log
        end
      elsif !leapfile_optional?(argv)
        puts
        puts " ="
        log :note, "There is no `Leapfile` in this directory, or any parent directory.\n"+
                   " =       "+
                   "Without this file, most commands will not be available."
        puts " ="
        puts
      end
    end

    #
    # Add a log entry for the leap command and leap platform versions.
    #
    def log_version(force=false)
      str = "leap command v#{LeapCli::VERSION}"
      if Util.is_git_directory?(LEAP_CLI_BASE_DIR)
        str << " (%s %s)" % [Util.current_git_branch(LEAP_CLI_BASE_DIR),
          Util.current_git_commit(LEAP_CLI_BASE_DIR)]
      else
        str << " (%s)" % LEAP_CLI_BASE_DIR
      end
      log str
      if LeapCli.leapfile.valid?
        str = "leap platform v#{Leap::Platform.version}"
        if Util.is_git_directory?(Path.platform)
          str << " (%s %s)" % [Util.current_git_branch(Path.platform), Util.current_git_commit(Path.platform)]
        end
        log str
      end
    end

    def parse_logging_options(argv)
      argv = argv.dup
      options = {:color => true, :verbose => 1}
      loop do
        current = argv.shift
        case current
          when '--verbose'  then options[:verbose] = argv.shift;
          when /-v[0-9]/    then options[:verbose] = current[-1];
          when '--log'      then options[:log] = argv.shift;
          when '--no-color' then options[:color] = false;
          when nil          then break;
        end
      end
      options
    end

    #
    # Returns true if loading the Leapfile is optional.
    #
    # We could make the 'new' command skip the 'pre' command, and then load Leapfile
    # from 'pre', but for various reasons we want the Leapfile loaded even earlier
    # than that. So, we need a way to test to see if loading the leapfile is optional
    # before any of the commands are loaded and the argument list is parsed by GLI.
    # Yes, hacky.
    #
    def leapfile_optional?(argv)
      if argv.include?('--version')
        return true
      else
        without_flags = argv.select {|i| i !~ /^-/}
        if without_flags.first == 'new'
          return true
        end
      end
      return false
    end

    #
    # loads the GLI command definition files
    #
    def load_commands(app)
      app.commands_from('leap_cli/commands')
      if Path.platform
        app.commands_from(Path.platform + '/lib/leap_cli/commands')
      end
    end

    #
    # loads the platform's macro definition files
    #
    def load_macros
      if Path.platform
        platform_macro_files = Dir[Path.platform + '/lib/leap_cli/macros/*.rb']
        if platform_macro_files.any?
          platform_macro_files.each do |macro_file|
            require macro_file
          end
        end
      end
    end

  end
end
