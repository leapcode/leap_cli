module LeapCli

  class ConfigError < StandardError
    attr_accessor :node
    def initialize(node, msg)
      @node = node
      super(msg)
    end
  end

  class FileMissing < StandardError
    attr_accessor :path, :options
    def initialize(path, options={})
      @path = path
      @options = options
    end
    def to_s
      @path
    end
  end

  class AssertionFailed < StandardError
    attr_accessor :assertion
    def initialize(assertion)
      @assertion = assertion
    end
    def to_s
      @assertion
    end
  end

end