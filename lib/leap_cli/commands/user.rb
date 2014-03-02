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

    desc 'Adds a new trusted sysadmin by adding public keys to the "users" directory.'
    arg_name 'USERNAME' #, :optional => false, :multiple => false
    command :'add-user' do |c|

      c.switch 'self', :desc => 'Add yourself as a trusted sysadin by choosing among the public keys available for the current user.', :negatable => false
      c.flag 'ssh-pub-key', :desc => 'SSH public key file for this new user'
      c.flag 'pgp-pub-key', :desc => 'OpenPGP public key file for this new user'

      c.action do |global_options,options,args|
        username = args.first
        if !username.any?
          if options[:self]
            username ||= `whoami`.strip
          else
            help! "Either USERNAME argument or --self flag is required."
          end
        end
        if Leap::Platform.reserved_usernames.include? username
          bail! %(The username "#{username}" is reserved. Sorry, pick another.)
        end

        ssh_pub_key = nil
        pgp_pub_key = nil

        if options['ssh-pub-key']
          key_type = `file -b #{options['ssh-pub-key']}`
          if not ["OpenSSH RSA public key","OpenSSH DSA public key","OpenSSH ECDSA public key"].include? key_type.strip()
              bail! %(The "#{options['ssh-pub-key']}" is not a valid ssh public key.)
          end
          ssh_pub_key = read_file!(options['ssh-pub-key'])
          key_name = File.basename(options['ssh-pub-key'])
          if not ["id_rsa.pub", "id_dsa.pub", "id_ecdsa.pub"].include? key_name
              log "You selected an ssh keyfile with non-standard name. Consider adding 'IdentityFile ~/.ssh/#{key_name.sub('.pub','')}' in ~/.ssh/config"
          end
        end
        if options['pgp-pub-key']
          pgp_pub_key = read_file!(options['pgp-pub-key'])
        end

        if options[:self]
          ssh_pub_key ||= pick_ssh_key.to_s
          pgp_pub_key ||= pick_pgp_key
        end

        assert!(ssh_pub_key, 'Sorry, could not find SSH public key.')

        if ssh_pub_key
          write_file!([:user_ssh, username], ssh_pub_key)
        end
        if pgp_pub_key
          write_file!([:user_pgp, username], pgp_pub_key)
        end

        update_authorized_keys
      end
    end

    #
    # let the the user choose among the ssh public keys that we encounter, or just pick the key if there is only one.
    #
    def pick_ssh_key
      ssh_keys = []
      Dir.glob("#{ENV['HOME']}/.ssh/*.pub").each do |keyfile|
        ssh_keys << SshKey.load(keyfile)
      end

      if `which ssh-add`.strip.any?
        `ssh-add -L 2> /dev/null`.split("\n").compact.each do |line|
          key = SshKey.load(line)
          key.comment = 'ssh-agent'
          ssh_keys << key unless ssh_keys.include?(key)
        end
      end
      ssh_keys.compact!

      assert! ssh_keys.any?, 'Sorry, could not find any SSH public key for you. Have you run ssh-keygen?'

      if ssh_keys.length > 1
        key_index = numbered_choice_menu('Choose your SSH public key', ssh_keys.collect(&:summary)) do |line, i|
          say("#{i+1}. #{line}")
        end
      else
        key_index = 0
      end

      key_type = `file -b #{ssh_keys[key_index].filename}`
      if not ["OpenSSH RSA public key","OpenSSH DSA public key","OpenSSH ECDSA public key"].include? key_type.strip()
          bail! %(The "#{ssh_keys[key_index].filename}" is not a valid ssh public key)
      end

      key_name  = File.basename(ssh_keys[key_index].filename)
      if not ["id_rsa.pub", "id_dsa.pub", "id_ecdsa.pub"].include? key_name
          log "You selected an ssh keyfile with non-standard name. Consider adding 'IdentityFile ~/.ssh/#{key_name.sub('.pub','')}' in ~/.ssh/config"
      end

      return ssh_keys[key_index]
    end

    #
    # let the the user choose among the gpg public keys that we encounter, or just pick the key if there is only one.
    #
    def pick_pgp_key
      secret_keys = GPGME::Key.find(:secret)
      if secret_keys.empty?
        log "Skipping OpenPGP setup because I could not find any OpenPGP keys for you"
        return nil
      end

      assert_bin! 'gpg'

      if secret_keys.length > 1
        key_index = numbered_choice_menu('Choose your OpenPGP public key', secret_keys) do |key, i|
          key_info = key.to_s.split("\n")[0..1].map{|line| line.sub(/^\s*(sec|uid)\s*/,'')}.join(' -- ')
          say("#{i+1}. #{key_info}")
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

  end
end
