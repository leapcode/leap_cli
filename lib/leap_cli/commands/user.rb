require 'gpgme'

#
# perhaps we want to verify that the key files are actually the key files we expect.
# we could use 'file' for this:
#
# > file ~/.gnupg/00440025.asc
# ~/.gnupg/00440025.asc: PGP public key block
#
# > file ~/.ssh/id_rsa.pub
# ~/.ssh/id_rsa.pub: OpenSSH RSA public key
#

module LeapCli
  module Commands

    desc 'Adds a new trusted sysadmin'
    arg_name '<username>', :optional => false, :multiple => false
    command :'add-user' do |c|

      c.switch 'self', :desc => 'lets you choose among your public keys', :negatable => false
      c.flag 'ssh-pub-key', :desc => 'SSH public key file for this new user'
      c.flag 'pgp-pub-key', :desc => 'OpenPGP public key file for this new user'

      c.action do |global_options,options,args|
        username = args.first
        if !username.any? && !options[:self]
          help! "Either 'username' or --self is required."
        end

        ssh_pub_key = nil
        pgp_pub_key = nil

        if options['ssh-pub-key']
          ssh_pub_key = read_file!(options['ssh-pub-key'])
        end
        if options['pgp-pub-key']
          pgp_pub_key = read_file!(options['pgp-pub-key'])
        end

        if options[:self]
          username ||= `whoami`.strip
          ssh_pub_key ||= pick_ssh_key
          pgp_pub_key ||= pick_pgp_key
        end

        assert!(ssh_pub_key, 'Sorry, could not find SSH public key.')
        #assert!(pgp_pub_key, 'Sorry, could not find OpenPGP public key.')

        if ssh_pub_key
          write_file!([:user_ssh, username], ssh_pub_key)
        end
        if pgp_pub_key
          write_file!([:user_pgp, username], pgp_pub_key)
        end

      end
    end

    #
    # let the the user choose among the ssh public keys that we encounter, or just pick the key if there is only one.
    #
    def pick_ssh_key
      assert_bin! 'ssh-add'
      ssh_fingerprints = `ssh-add -l`.split("\n").compact
      assert! ssh_fingerprints.any?, 'Sorry, could not find any SSH public key for you. Have you run ssh-keygen?'

      if ssh_fingerprints.length > 1
        key_index = numbered_choice_menu('Choose your SSH public key', ssh_fingerprints) do |key, i|
          say("#{i+1}.  #{key}")
        end
      else
        key_index = 0
      end

      ssh_keys = `ssh-add -L`.split("\n").compact
      return ssh_keys[key_index]
    end

    #
    # let the the user choose among the gpg public keys that we encounter, or just pick the key if there is only one.
    #
    def pick_pgp_key
      secret_keys = GPGME::Key.find(:secret)

      assert_bin! 'gpg'
      assert! secret_keys.any?, 'Sorry, could not find any OpenPGP keys for you.'

      if secret_keys.length > 1
        key_index = numbered_choice_menu('Choose your OpenPGP public key', secret_keys) do |key, i|
          key_info = key.to_s.split("\n")[0..1].map{|line| line.sub(/^\s*(sec|uid)\s*/,'')}.join(' -- ')
          say("#{i+1}.  #{key_info}")
        end
      else
        key_index = 0
      end

      key_id = secret_keys[key_index].sha

      # can't use this, it includes signatures:
      #puts GPGME::Key.export(key_id, :armor => true, :export_options => :export_minimal)

      # export with signatures removed:
      return `gpg --armor --export-options export-minimal --export #{key_id}`.strip
    end

    def update_authorized_keys
      buffer = StringIO.new
      Dir.glob(path([:user_ssh, '*'])).each do |keyfile|
        buffer << File.read(keyfile)
      end
      write_file!(:authorized_keys, buffer.string)
    end

  end
end