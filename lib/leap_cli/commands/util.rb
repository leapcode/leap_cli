module LeapCli
  module Commands
    extend self
    extend LeapCli::Util

    #
    # keeps prompting the user for a numbered choice, until they pick a good one or bail out.
    #
    # block is yielded and is responsible for rendering the choices.
    #
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


  end
end
