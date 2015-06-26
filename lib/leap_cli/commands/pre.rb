
#
# check to make sure we can find the root directory of the platform
#
module LeapCli; module Commands

  desc 'Verbosity level 0..5'
  arg_name 'LEVEL'
  default_value '1'
  flag [:v, :verbose]

  desc 'Override default log file.'
  arg_name 'FILE'
  default_value nil
  flag :log

  desc 'Display version number and exit.'
  switch :version, :negatable => false

  desc 'Skip prompts and assume "yes".'
  switch :yes, :negatable => false

  desc 'Like --yes, but also skip prompts that are potentially dangerous to skip.'
  switch :force, :negatable => false

  desc 'Print full stack trace for exceptions and load `debugger` gem if installed.'
  switch [:d, :debug], :negatable => false

  desc 'Disable colors in output.'
  default_value true
  switch 'color', :negatable => true

  pre do |global,command,options,args|
    if global[:force]
      global[:yes] = true
    end
    initialize_leap_cli(true, global)
    true
  end

  protected

  #
  # available options:
  #  :verbose -- integer log verbosity level
  #  :log     -- log file path
  #  :color   -- true or false, to log in color or not.
  #
  def initialize_leap_cli(require_provider, options={})
    if Process::Sys.getuid == 0
      bail! "`leap` should not be run as root."
    end

    # set verbosity
    options[:verbose] ||= 1
    LeapCli.set_log_level(options[:verbose].to_i)

    # load Leapfile
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
    elsif require_provider
      bail! { log :missing, 'Leapfile in directory tree' }
    end

    # set log file
    LeapCli.log_file = options[:log] || LeapCli.leapfile.log
    LeapCli::Util.log_raw(:log) { $0 + ' ' + ORIGINAL_ARGV.join(' ')}
    log_version
    LeapCli.log_in_color = options[:color]
  end

  #
  # add a log entry for the leap command and leap platform versions
  #
  def log_version
    if LeapCli.log_level >= 2
      str = "leap command v#{LeapCli::VERSION}"
      if Util.is_git_directory?(LEAP_CLI_BASE_DIR)
        str << " (%s %s)" % [Util.current_git_branch(LEAP_CLI_BASE_DIR),
          Util.current_git_commit(LEAP_CLI_BASE_DIR)]
      else
        str << " (%s)" % LEAP_CLI_BASE_DIR
      end
      log 2, str
      if LeapCli.leapfile.valid?
        str = "leap platform v#{Leap::Platform.version}"
        if Util.is_git_directory?(Path.platform)
          str << " (%s %s)" % [Util.current_git_branch(Path.platform), Util.current_git_commit(Path.platform)]
        end
        log 2, str
      end
    end
  end

end; end
