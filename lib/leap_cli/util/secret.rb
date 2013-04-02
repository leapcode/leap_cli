#
# A simple secret generator
#
# Uses OpenSSL random number generator instead of Ruby's rand function
#
require 'openssl'

module LeapCli; module Util
  class Secret
    CHARS = ('A'..'Z').to_a + ('a'..'z').to_a + ('0'..'9').to_a + "_".split(//u) - "io01lO".split(//u)
    HEX = (0..9).to_a + ('a'..'f').to_a

    #
    # generate a secret with with no ambiguous characters.
    #
    # +length+ is in chars
    #
    # Only alphanumerics are allowed, in order to make these passwords work
    # for REST url calls and to allow you to easily copy and paste them.
    #
    def self.generate(length = 16)
      seed
      OpenSSL::Random.random_bytes(length).bytes.to_a.collect { |byte|
        CHARS[ byte % CHARS.length ]
      }.join
    end

    #
    # generates a hex secret, instead of an alphanumeric on.
    #
    # length is in bits
    #
    def self.generate_hex(length = 128)
      seed
      OpenSSL::Random.random_bytes(length/4).bytes.to_a.collect { |byte|
        HEX[ byte % HEX.length ]
      }.join
    end

    private

    def self.seed
      @pid ||= 0
      pid = $$
      if @pid != pid
        now = Time.now
        OpenSSL::Random.seed( [now.to_i, @pid, pid].join )
        @pid = pid
      end
    end

  end
end; end
