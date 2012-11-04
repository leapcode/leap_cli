module LeapCli
  extend self

  def log_level
    @log_level
  end

  def log_level=(value)
    @log_level = value
  end
end

##
## LOGGING
##

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

def progress(message)
  log1("  = " + message)
end

def progress2(message)
  log2("  = " + message)
end
