
#
# check to make sure we can find the root directory of the platform
#
module LeapCli
  module Commands

    desc 'Verbosity level 0..2'
    arg_name 'level'
    default_value '0'
    flag [:v, :verbose]

    desc 'Specify the root directory'
    arg_name 'path'
    default_value Path.root
    flag [:root]

    pre do |global,command,options,args|
      #
      # set verbosity
      #
      LeapCli.log_level = global[:verbose].to_i

      #
      # require a root directory
      #
      if global[:root]
        Path.set_root(global[:root])
      end
      if Path.ok?
        true
      else
        fail!("Could not find the root directory. Change current working directory or try --root")
      end
    end

  end
end
