module LeapCli
  module Commands
    extend self
    extend LeapCli::Util
#     #
#     # keeps prompting the user for a numbered choice, until they pick a good one or bail out.
#     #
#     # block is yielded and is responsible for rendering the choices.
#     #
    def numbered_choice_menu(msg, items, &block)
      while true
        say("\n" + msg + ':')
        items.each_with_index &block
        say("q.  quit")
        index = ask("number 1-#{items.length}> ")
        if index.empty?
          next
        elsif index =~ /q/
          bail!
        else
          i = index.to_i - 1
          if i < 0 || i >= items.length
            bail!
          else
            return i
          end
        end
      end
    end

#     #
#     # read a file, exit if the file doesn't exist.
#     #
#     def read_file!(file_path)
#       if !File.exists?(file_path)
#         bail!("File '%s' does not exist." % file_path)
#       else
#         File.readfile(file_path)
#       end
#     end

#     ##
#     ## LOGGING
#     ##

#     def log0(message=nil, &block)
#       if message
#         puts message
#       elsif block
#         puts yield(block)
#       end
#     end

#     def log1(message=nil, &block)
#       if LeapCli.log_level > 0
#         if message
#           puts message
#         elsif block
#           puts yield(block)
#         end
#       end
#     end

#     def log2(message=nil, &block)
#       if LeapCli.log_level > 1
#         if message
#           puts message
#         elsif block
#           puts yield(block)
#         end
#       end
#     end

#     def progress(message)
#       log1(" * " + message)
#     end

#     ##
#     ## QUITTING
#     ##

#     #
#     # quit and print help
#     #
#     def help!(message=nil)
#       ENV['GLI_DEBUG'] = "false"
#       help_now!(message)
#       #say("ERROR: " + message)
#     end

#     #
#     # quit with a message that we are bailing out.
#     #
#     def bail!(message="")
#       say(message)
#       say("Bailing out.")
#       raise SystemExit.new
#       #ENV['GLI_DEBUG'] = "false"
#       #exit_now!(message)
#     end

#     #
#     # quit with no message
#     #
#     def quit!(message='')
#       say(message)
#       raise SystemExit.new
#     end

#     #
#     # bails out with message if assertion is false.
#     #
#     def assert!(boolean, message)
#       bail!(message) unless boolean
#     end

#     #
#     # assert that the command is available
#     #
#     def assert_bin!(cmd_name)
#       assert! `which #{cmd_name}`.strip.any?, "Sorry, bailing out, the command '%s' is not installed." % cmd_name
#     end

  end
end
