require 'openssl'
require 'certificate_authority'
require 'date'
require 'digest/md5'

module LeapCli; module Commands

  desc 'Creates the public and private key for your Certificate Authority.'
  command :'init-ca' do |c|
    c.action do |global_options,options,args|
      assert_files_missing! :ca_cert, :ca_key
      assert_config! 'provider.ca.name'
      assert_config! 'provider.ca.bit_size'

      provider = manager.provider
      root = CertificateAuthority::Certificate.new

      # set subject
      root.subject.common_name = provider.ca.name
      possible = ['country', 'state', 'locality', 'organization', 'organizational_unit', 'email_address']
      provider.ca.keys.each do |key|
        if possible.include?(key)
          root.subject.send(key + '=', provider.ca[key])
        end
      end

      # set expiration
      years = 2
      today = Date.today
      root.not_before = Time.gm today.year, today.month, today.day
      root.not_after = root.not_before + years * 60 * 60 * 24 * 365

      # generate private key
      root.serial_number.number = 1
      root.key_material.generate_key(provider.ca.bit_size)

      # sign self
      root.signing_entity = true
      root.parent = root
      root.sign!(ca_root_signing_profile)

      # save
      write_file!(:ca_key, root.key_material.private_key.to_pem)
      write_file!(:ca_cert, root.to_pem)
    end
  end

  desc 'Creates or renews a X.509 certificate/key pair for a single node or all nodes'
  arg_name '<node-name | "all">', :optional => false, :multiple => false
  command :'update-cert' do |c|
    c.action do |global_options,options,args|
      assert_files_exist! :ca_cert, :ca_key, :msg => 'Run init-ca to create them'
      assert_config! 'provider.ca.server_certificates.bit_size'
      assert_config! 'provider.ca.server_certificates.life_span'

      if args.first == 'all'
        bail! 'not supported yet'
      else
        provider = manager.provider
        ca_root  = cert_from_files(:ca_cert, :ca_key)
        node     = get_node_from_args(args)

        # set subject
        cert = CertificateAuthority::Certificate.new
        cert.subject.common_name = node.domain.full

        # set expiration
        years = provider.ca.server_certificates.life_span.to_i
        today = Date.today
        cert.not_before = Time.gm today.year, today.month, today.day
        cert.not_after = cert.not_before + years * 60 * 60 * 24 * 365

        # generate key
        cert.serial_number.number = cert_serial_number(node.domain.full)
        cert.key_material.generate_key(provider.ca.server_certificates.bit_size)

        # sign
        cert.parent = ca_root
        cert.sign!(server_signing_profile(node))

        # save
        write_file!([:node_x509_key, node.name], cert.key_material.private_key.to_pem)
        write_file!([:node_x509_cert, node.name], cert.to_pem)
      end
    end
  end

  desc 'Generates Diffie-Hellman parameter file (needed for server-side of TLS connections)'
  command :'init-dh' do |c|
    c.action do |global_options,options,args|
      long_running do
        if cmd_exists?('certtool')
          progress('Generating DH parameters (takes a long time)...')
          output = assert_run!('certtool --generate-dh-params --sec-param high')
          write_file!(:dh_params, output)
        else
          progress('Generating DH parameters (takes a REALLY long time)...')
          output = OpenSSL::PKey::DH.generate(3248).to_pem
          write_file!(:dh_params, output)
        end
      end
    end
  end

  private

  def cert_from_files(crt, key)
    crt = read_file!(crt)
    key = read_file!(key)
    openssl_cert = OpenSSL::X509::Certificate.new(crt)
    cert = CertificateAuthority::Certificate.from_openssl(openssl_cert)
    cert.key_material.private_key = OpenSSL::PKey::RSA.new(key)  # second argument is password, if set
    return cert
  end

  def ca_root_signing_profile
    {
      "extensions" => {
        "basicConstraints" => {"ca" => true},
        "keyUsage" => {
          "usage" => ["critical", "keyCertSign"]
        },
        "extendedKeyUsage" => {
          "usage" => []
        }
      }
    }
  end

  #
  # for keyusage, openvpn server certs can have keyEncipherment or keyAgreement. I am not sure which is preferable.
  # going with keyAgreement for now.
  #
  def server_signing_profile(node)
    {
      "extensions" => {
        "keyUsage" => {
          "usage" => ["digitalSignature", "keyAgreement"]
        },
        "extendedKeyUsage" => {
          "usage" => ["serverAuth"]
        },
        "subjectAltName" => {
          "uris" => [
            "IP:#{node.ip_address}",
            "DNS:#{node.domain.internal}"
          ]
        }
      }
    }
  end

  #
  # For cert serial numbers, we need a non-colliding number less than 160 bits.
  # md5 will do nicely, since there is no need for a secure hash, just a short one.
  # (md5 is 128 bits)
  #
  def cert_serial_number(domain_name)
    Digest::MD5.hexdigest("#{domain_name} -- #{Time.now}").to_i(16)
  end

end; end
