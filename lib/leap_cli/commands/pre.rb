
#
# check to make sure we can find the root directory of the platform
#
module LeapCli; module Commands

  desc 'Verbosity level 0..5'
  arg_name 'LEVEL'
  default_value '1'
  flag [:v, :verbose]

  desc 'Override default log file'
  arg_name 'FILE'
  default_value nil
  flag :log

  desc 'Display version number and exit'
  switch :version, :negatable => false

  desc 'Skip prompts and assume "yes"'
  switch :yes, :negatable => false

  desc 'Enable debugging library (leap_cli development only)'
  switch :debug, :negatable => false

  desc 'Disable colors in output'
  default_value true
  switch 'color', :negatable => true

  pre do |global,command,options,args|
    #
    # set verbosity
    #
    LeapCli.log_level = global[:verbose].to_i

    #
    # load Leapfile
    #
    unless LeapCli.leapfile.load
      bail! { log :missing, 'Leapfile in directory tree' }
    end
    Path.set_platform_path(LeapCli.leapfile.platform_directory_path)
    Path.set_provider_path(LeapCli.leapfile.provider_directory_path)
    if !Path.provider || !File.directory?(Path.provider)
      bail! { log :missing, "provider directory '#{Path.provider}'" }
    end
    if !Path.platform || !File.directory?(Path.platform)
      bail! { log :missing, "platform directory '#{Path.platform}'" }
    end

    #
    # set log file
    #
    LeapCli.log_file = global[:log] || LeapCli.leapfile.log
    LeapCli::Util.log_raw(:log) { $0 + ' ' + ORIGINAL_ARGV.join(' ')}
    log_version
    LeapCli.log_in_color = global[:color]

    true
  end

  private

  #
  # add a log entry for the leap command and leap platform versions
  #
  def log_version
    if LeapCli.log_level >= 2
      str = "leap command v#{LeapCli::VERSION}"
      cli_dir = File.dirname(__FILE__)
      if Util.is_git_directory?(cli_dir)
        str << " (%s %s)" % [Util.current_git_branch(cli_dir), Util.current_git_commit(cli_dir)]
      end
      log 2, str
      str = "leap platform v#{Leap::Platform.version}"
      if Util.is_git_directory?(Path.platform)
        str << " (%s %s)" % [Util.current_git_branch(Path.platform), Util.current_git_commit(Path.platform)]
      end
      log 2, str
    end
  end


end; end
