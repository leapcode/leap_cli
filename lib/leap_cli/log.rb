module LeapCli

  def self.log_level
    @log_level
  end

  def self.log_level=(value)
    @log_level = value
  end

end

def log0(message=nil, &block)
  if message
    puts message
  elsif block
    puts yield(block)
  end
end

def log1(message=nil, &block)
  if LeapCli.log_level > 0
    if message
      puts message
    elsif block
      puts yield(block)
    end
  end
end

def log2(message=nil, &block)
  if LeapCli.log_level > 1
    if message
      puts message
    elsif block
      puts yield(block)
    end
  end
end

def help!(message=nil)
  ENV['GLI_DEBUG'] = "false"
  help_now!(message)
end

def fail!(message=nil)
  ENV['GLI_DEBUG'] = "false"
  exit_now!(message)
end