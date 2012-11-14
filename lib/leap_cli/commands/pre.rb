
#
# check to make sure we can find the root directory of the platform
#
module LeapCli
  module Commands

    desc 'Verbosity level 0..2'
    arg_name 'level'
    default_value '1'
    flag [:v, :verbose]

    desc 'Specify the root directory'
    arg_name 'path'
    default_value Path.root
    flag [:root]

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
      # require a root directory
      #
      if global[:root]
        Path.set_root(global[:root])
      end
      if Path.ok?
        true
      else
        bail!("Could not find the root directory. Change current working directory or try --root")
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
