require 'readline'

module LeapCli; module Commands

  extend LeapCli::LogCommand
  extend LeapCli::Util

  def path(name)
    Path.named_path(name)
  end

  #
  # keeps prompting the user for a numbered choice, until they pick a good one or bail out.
  #
  # block is yielded and is responsible for rendering the choices.
  #
  def numbered_choice_menu(msg, items, &block)
    while true
      say("\n" + msg + ':')
      items.each_with_index(&block)
      say("q. quit")
      index = ask("number 1-#{items.length}> ")
      if index.nil? || index.empty?
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

  def parse_node_list(nodes)
    if nodes.is_a? Config::Object
      Config::ObjectList.new(nodes)
    elsif nodes.is_a? Config::ObjectList
      nodes
    elsif nodes.is_a? String
      manager.filter!(nodes)
    else
      bail! "argument error"
    end
  end

  def say(statement)
    if ends_in_whitespace?(statement)
      $stdout.print(statement)
      $stdout.flush
    else
      $stdout.puts(statement)
    end
  end

  def ask(question, options={})
    default = options[:default]
    if default
      if ends_in_whitespace?(question)
        question = question + "|" + default + "| "
      else
        question = question + "|" + default + "|"
      end
    end
    response = Readline.readline(question, true) # set to false if ever reading passwords.
    if response
      response = response.strip
      if response.empty?
        return default
      else
        return response
      end
    else
      return default
    end
  end

  def agree(question, options={})
    while true
      response = ask(question, options)
      if response.nil?
        say('Please enter "yes" or "no".')
      elsif ["y","yes", "ye"].include?(response.downcase)
        return true
      elsif ["n", "no"].include?(response.downcase)
        return false
      else
        say('Please enter "yes" or "no".')
      end
    end
  end

  private

  # true if str ends in whitespace before a color escape code.
  def ends_in_whitespace?(str)
    /[ \t](\e\[\d+(;\d+)*m)?\Z/ =~ str
  end

end; end
