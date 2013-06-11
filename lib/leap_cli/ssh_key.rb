#
# A wrapper around OpenSSL::PKey::RSA instances to provide a better api for dealing with SSH keys.
#
#

require 'net/ssh'
require 'forwardable'

module LeapCli
  class SshKey
    extend Forwardable

    attr_accessor :filename
    attr_accessor :comment

    ##
    ## CLASS METHODS
    ##

    def self.load(arg1, arg2=nil)
      key = nil
      if arg1.is_a? OpenSSL::PKey::RSA
        key = SshKey.new arg1
      elsif arg1.is_a? String
        if arg1 =~ /^ssh-/
          type, data = arg1.split(' ')
          key = SshKey.new load_from_data(data, type)
        elsif File.exists? arg1
          key = SshKey.new load_from_file(arg1)
          key.filename = arg1
        else
          key = SshKey.new load_from_data(arg1, arg2)
        end
      end
      return key
    end

    def self.load_from_file(filename)
      public_key = nil
      private_key = nil
      begin
        public_key = Net::SSH::KeyFactory.load_public_key(filename)
      rescue NotImplementedError, Net::SSH::Exception, OpenSSL::PKey::PKeyError
        begin
          private_key = Net::SSH::KeyFactory.load_private_key(filename)
        rescue NotImplementedError, Net::SSH::Exception, OpenSSL::PKey::PKeyError
        end
      end
      public_key || private_key
    end

    def self.load_from_data(data, type='ssh-rsa')
      public_key = nil
      private_key = nil
      begin
        public_key = Net::SSH::KeyFactory.load_data_public_key("#{type} #{data}")
      rescue NotImplementedError, Net::SSH::Exception, OpenSSL::PKey::PKeyError
        begin
          private_key = Net::SSH::KeyFactory.load_data_private_key("#{type} #{data}")
        rescue NotImplementedError, Net::SSH::Exception, OpenSSL::PKey::PKeyError
        end
      end
      public_key || private_key
    end

    ##
    ## INSTANCE METHODS
    ##

    public

    def initialize(rsa_key)
      @key = rsa_key
    end

    def_delegator :@key, :fingerprint, :fingerprint
    def_delegator :@key, :public?, :public?
    def_delegator :@key, :private?, :private?
    def_delegator :@key, :ssh_type, :type
    def_delegator :@key, :public_encrypt, :public_encrypt
    def_delegator :@key, :public_decrypt, :public_decrypt
    def_delegator :@key, :private_encrypt, :private_encrypt
    def_delegator :@key, :private_decrypt, :private_decrypt
    def_delegator :@key, :params, :params

    def public_key
      SshKey.new(@key.public_key)
    end

    def private_key
      SshKey.new(@key.private_key)
    end

    #
    # not sure if this will always work, but is seems to for now.
    #
    def bits
      Net::SSH::Buffer.from(:key, @key).to_s.split("\001\000").last.size * 8
    end

    def summary
      "%s %s %s (%s)" % [self.type, self.bits, self.fingerprint, self.filename || self.comment || '']
    end

    def to_s
      self.type + " " + self.key
    end

    def key
      [Net::SSH::Buffer.from(:key, @key).to_s].pack("m*").gsub(/\s/, "")
    end

    def ==(other_key)
      return false if other_key.nil?
      return false if self.class != other_key.class
      return self.to_text == other_key.to_text
    end

    def in_known_hosts?(*identifiers)
      identifiers.each do |identifier|
        Net::SSH::KnownHosts.search_for(identifier).each do |key|
          return true if self == key
        end
      end
      return false
    end

  end
end
