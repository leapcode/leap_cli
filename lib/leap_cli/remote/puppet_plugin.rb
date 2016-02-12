#
# these methods are made available in capistrano tasks as 'puppet.method_name'
# (see RemoteCommand::new_capistrano)
#

module LeapCli; module Remote; module PuppetPlugin

  def apply(options)
    run "#{Leap::Platform.leap_dir}/bin/puppet_command set_hostname apply #{flagize(options)}"
  end

  private

  def flagize(hsh)
    hsh.inject([]) {|str, item|
      if item[1] === false
        str
      elsif item[1] === true
        str << "--" + item[0].to_s
      else
        str << "--" + item[0].to_s + " " + item[1].inspect
      end
    }.join(' ')
  end

end; end; end
