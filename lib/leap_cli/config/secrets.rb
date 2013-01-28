#
#
# A class for the secrets.json file
#
#

module LeapCli; module Config

  class Secrets < Object
    attr_reader :node_list

    def initialize(manager=nil)
      super(manager)
      @discovered_keys = {}
    end

    def set(key, value)
      key = key.to_s
      @discovered_keys[key] = true
      self[key] ||= value
    end

    def dump_json
      self.each_key do |key|
        unless @discovered_keys[key]
          self.delete(key)
        end
      end
      super
    end
  end

end; end
