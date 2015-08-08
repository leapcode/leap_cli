#
# Configuration class for provider.json
#

module LeapCli; module Config
  class Provider < Object
    attr_reader :environment
    def set_env(e)
      @environment = e
    end
    def provider
      self
    end
  end
end; end
