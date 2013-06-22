#
# Configuration for a 'node' (a server in the provider's infrastructure)
#

require 'ipaddr'

module LeapCli; module Config

  class Node < Object
    attr_accessor :file_paths

    def initialize(manager=nil)
      super(manager)
      @node = self
      @file_paths = []
    end

    #
    # returns true if this node has an ip address in the range of the vagrant network
    #
    def vagrant?
      begin
        vagrant_range = IPAddr.new LeapCli.leapfile.vagrant_network
      rescue ArgumentError => exc
        Util::bail! { Util::log :invalid, "ip address '#{@node.ip_address}' vagrant.network" }
      end

      begin
        ip_address = IPAddr.new @node.get('ip_address')
      rescue ArgumentError => exc
        Util::log :warning, "invalid ip address '#{@node.get('ip_address')}' for node '#{@node.name}'"
      end
      return vagrant_range.include?(ip_address)
    end
  end

end; end
