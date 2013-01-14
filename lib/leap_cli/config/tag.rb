#
#
# A class for node services or node tags.
#
#

module LeapCli; module Config

  class Tag < Object
    attr_reader :node_list

    def initialize(manager=nil)
      super(manager)
      @node_list = Config::ObjectList.new
    end
  end

end; end
