
#
# check to make sure we can find the root directory of the platform
#
module LeapCli
  module Commands

    desc 'Verbosity level 0..2'
    arg_name 'level'
    default_value '1'
    flag [:v, :verbose]

    desc 'Display version number and exit'
    switch :version, :negatable => false

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

      #
      # check requirements
      #
      REQUIREMENTS.each do |key|
        assert_config! key
      end

    end

  end
end
