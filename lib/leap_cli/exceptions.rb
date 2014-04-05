module LeapCli

  class ConfigError < StandardError
    attr_accessor :node
    def initialize(node, msg)
      @node = node
      super(msg)
    end
  end

end