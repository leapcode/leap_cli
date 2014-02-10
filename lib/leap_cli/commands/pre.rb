
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

  pre do |global,command,options,args|
    #
    # set verbosity
    #
    LeapCli.log_level = global[:verbose].to_i
    if LeapCli.log_level > 1
      ENV['GLI_DEBUG'] = "true"
    else
      ENV['GLI_DEBUG'] = "false"
    end

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

    if LeapCli.leapfile.platform_branch && LeapCli::Util.is_git_directory?(Path.platform)
      branch = LeapCli::Util.current_git_branch(Path.platform)
      if branch != LeapCli.leapfile.platform_branch
        bail! "Wrong branch for #{Path.platform}. Was '#{branch}', should be '#{LeapCli.leapfile.platform_branch}'. Edit Leapfile to disable this check."
      end
    end

    #
    # set log file
    #
    LeapCli.log_file = global[:log] || LeapCli.leapfile.log
    LeapCli::Util.log_raw(:log) { $0 + ' ' + ORIGINAL_ARGV.join(' ')}
    log_version

    #
    # load all the nodes everything
    #
    manager

    #
    # check requirements
    #
    REQUIREMENTS.each do |key|
      assert_config! key
    end

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
