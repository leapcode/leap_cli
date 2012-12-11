#
# A simple alphanumeric secret generator, with no ambiguous characters.
#
# Only alphanumerics are allows, in order to make these passwords work
# for REST url calls and to allow you to easily copy and past them.
#
# Uses OpenSSL random number generator instead of Ruby's rand function
#

require 'openssl'

module LeapCli; module Util

  class Secret

    CHARS = ('A'..'Z').to_a + ('a'..'z').to_a + ('0'..'9').to_a + "_".split(//u) - "io01lO".split(//u)

    def self.generate(length = 16)
      seed
      OpenSSL::Random.random_bytes(length).bytes.to_a.collect { |byte|
        CHARS[ byte % CHARS.length ]
      }.join
    end

    def self.seed
      @pid ||= 0
      pid = $$
      if @pid != pid
        now = Time.now
        OpenSSL::Random.seed( [now.to_i, now.nsec, @pid, pid].join )
        @pid = pid
      end
    end

  end

end; end
