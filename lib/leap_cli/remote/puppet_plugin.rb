#
# these methods are made available in capistrano tasks as 'puppet.method_name'
# (see RemoteCommand::new_capistrano)
#

module LeapCli; module Remote; module PuppetPlugin

  def apply(options)
    run "#{PUPPET_DESTINATION}/bin/puppet_command set_hostname apply #{flagize(options)}"
  end

  private

  def flagize(hsh)
    hsh.inject([]) {|str, item|
      if item[1] === false
        str
      elsif item[1] === true
        str << "--" + item[0].to_s
      else
        str << "--" + item[0].to_s + " " + item[1].to_s
      end
    }.join(' ')
  end

end; end; end


    # def puppet(command = :noop)
    #   #puppet_cmd = "cd #{puppet_destination} && #{sudo_cmd} #{puppet_command} --modulepath=#{puppet_lib} #{puppet_parameters}"
    #   puppet_cmd = "cd #{puppet_destination} && #{sudo_cmd} #{puppet_command} #{puppet_parameters}"
    #   flag = command == :noop ? '--noop' : ''

    #   writer = if puppet_stream_output
    #              SupplyDrop::Writer::Streaming.new(logger)
    #            else
    #              SupplyDrop::Writer::Batched.new(logger)
    #            end

    #   writer = SupplyDrop::Writer::File.new(writer, puppet_write_to_file) unless puppet_write_to_file.nil?

    #   begin
    #     exitcode = nil
    #     run "#{puppet_cmd} #{flag}; echo exitcode:$?" do |channel, stream, data|
    #       if data =~ /exitcode:(\d+)/
    #         exitcode = $1
    #         writer.collect_output(channel[:host], "Puppet #{command} complete (#{exitcode_description(exitcode)}).\n")
    #       else
    #         writer.collect_output(channel[:host], data)
    #       end
    #     end
    #   ensure
    #     writer.all_output_collected
    #   end
    # end

    # def exitcode_description(code)
    #   case code
    #     when "0" then "no changes"
    #     when "2" then "changes made"
    #     when "4" then "failed"
    #     when "6" then "changes and failures"
    #     else code
    #   end
    # end

