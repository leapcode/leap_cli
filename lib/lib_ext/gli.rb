#
# print subcommands indented in the main global help screen
#

module GLI
  module Commands
    module HelpModules
      class GlobalHelpFormat
        SUB_CMD_INDENT = "  "
        def format
          program_desc = @app.program_desc
          program_long_desc = @app.program_long_desc
          if program_long_desc
            wrapper = @wrapper_class.new(Terminal.instance.size[0],4)
            program_long_desc = "\n    #{wrapper.wrap(program_long_desc)}\n\n" if program_long_desc
          else
            program_long_desc = "\n"
          end

          # build a list of commands, sort them so the commands with subcommands are at the bottom
          commands = @sorter.call(@app.commands_declaration_order.reject(&:nodoc)).sort do |a,b|
            if a.commands.any? && b.commands.any?;  a.name <=> b.name
            elsif a.commands.any?;                  1
            elsif b.commands.any?;                 -1
            else;                                   a.name <=> b.name
            end
          end

          # build a list of command info ([name, description]), including subcommands if appropriate
          command_info_list = []
          commands.each do |command|
            name = [command.name, Array(command.aliases)].flatten.join(', ')
            command_info_list << [name, command.description]
            if command.commands.any?
              @sorter.call(command.commands_declaration_order).each do |cmd|
                if command.get_default_command == cmd.name
                  command_info_list << [SUB_CMD_INDENT + cmd.names,cmd.description + " (default)"]
                else
                  command_info_list << [SUB_CMD_INDENT + cmd.names,cmd.description]
                end
              end
            end
          end

          # display
          command_formatter = ListFormatter.new(command_info_list, @wrapper_class)
          stringio = StringIO.new
          command_formatter.output(stringio)
          commands = stringio.string
          global_option_descriptions = OptionsFormatter.new(global_flags_and_switches,@wrapper_class).format
          GLOBAL_HELP.result(binding)
        end
      end
    end
  end
end
