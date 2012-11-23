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
      assert_config! 'provider.ca.life_span'

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
      root.not_before = today
      root.not_after = years_from_today(provider.ca.life_span.to_i)

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
      assert_config! 'provider.ca.server_certificates.digest'
      assert_config! 'provider.ca.server_certificates.life_span'
      assert_config! 'common.x509.use'

      if args.first == 'all' || args.empty?
        manager.each_node do |node|
          if cert_needs_updating?(node)
            generate_cert_for_node(node)
          end
        end
      else
        generate_cert_for_node(get_node_from_args(args))
      end
    end
  end

  desc 'Generates Diffie-Hellman parameter file (needed for server-side of TLS connections)'
  command :'init-dh' do |c|
    c.action do |global_options,options,args|
      long_running do
        if cmd_exists?('certtool')
          log 0, 'Generating DH parameters (takes a long time)...'
          output = assert_run!('certtool --generate-dh-params --sec-param high')
          output.sub! /.*(-----BEGIN DH PARAMETERS-----.*-----END DH PARAMETERS-----).*/m, '\1'
          output << "\n"
          write_file!(:dh_params, output)
        else
          log 0, 'Generating DH parameters (takes a REALLY long time)...'
          output = OpenSSL::PKey::DH.generate(3248).to_pem
          write_file!(:dh_params, output)
        end
      end
    end
  end

  #
  # hints:
  #
  # inspect CSR:
  #   openssl req -noout -text -in files/cert/x.csr
  #
  # generate CSR with openssl to see how it compares:
  #   openssl req -sha256 -nodes -newkey rsa:2048 -keyout example.key -out example.csr
  #
  # validate a CSR:
  #   http://certlogik.com/decoder/
  #
  # nice details about CSRs:
  #   http://www.redkestrel.co.uk/Articles/CSR.html
  #
  desc 'Creates a Certificate Signing Request for use in purchasing a commercial x509 certificate'
  command :'init-csr' do |c|
    #c.switch 'sign', :desc => 'additionally creates a cert that is signed by your own CA (recommended only for testing)', :negatable => false
    c.action do |global_options,options,args|
      assert_config! 'provider.domain'
      assert_config! 'provider.name'
      assert_config! 'provider.default_language'
      assert_config! 'provider.ca.server_certificates.bit_size'
      assert_config! 'provider.ca.server_certificates.digest'
      assert_files_missing! [:commercial_key, manager.provider.domain], [:commercial_csr, manager.provider.domain], :msg => 'If you really want to create a new key and CSR, remove these files first.'
      if options[:sign]
        assert_files_exist! :ca_cert, :ca_key, :msg => 'Run init-ca to create them'
      end

      # RSA key
      keypair = CertificateAuthority::MemoryKeyMaterial.new
      log :generating, "%s bit RSA key" % manager.provider.ca.server_certificates.bit_size do
        keypair.generate_key(manager.provider.ca.server_certificates.bit_size)
        write_file! [:commercial_key, manager.provider.domain], keypair.private_key.to_pem
      end

      # CSR
      dn  = CertificateAuthority::DistinguishedName.new
      csr = CertificateAuthority::SigningRequest.new
      dn.common_name = manager.provider.domain
      dn.organization = manager.provider.name[manager.provider.default_language]
      log :generating, "CSR with commonName => '%s', organization => '%s'" % [dn.common_name, dn.organization] do
        csr.distinguished_name = dn
        csr.key_material = keypair
        csr.digest = manager.provider.ca.server_certificates.digest
        request = csr.to_x509_csr
        write_file! [:commercial_csr, manager.provider.domain], csr.to_pem
      end

      # Sign using our own CA, for use in testing but hopefully not production.
      # It is not that commerical CAs are so secure, it is just that signing your own certs is
      # a total drag for the user because they must click through dire warnings.
      #if options[:sign]
        log :generating, "self-signed x509 server certificate for testing purposes" do
          cert = csr.to_cert
          cert.serial_number.number = cert_serial_number(manager.provider.domain)
          cert.not_before = today
          cert.not_after  = years_from_today(1)
          cert.parent = ca_root
          cert.sign! domain_test_signing_profile
          write_file! [:commercial_cert, manager.provider.domain], cert.to_pem
          log "please replace this file with the real certificate you get from a CA using #{Path.relative_path([:commercial_csr, manager.provider.domain])}"
        end
      #end
    end
  end

  private

  def cert_needs_updating?(node)
    if !file_exists?([:node_x509_cert, node.name], [:node_x509_key, node.name])
      return true
    else
      cert = load_certificate_file([:node_x509_cert, node.name])
      if cert.not_after < months_from_today(1)
        log :updating, "cert for node '#{node.name}' because it will expire soon"
        return true
      end
      if cert.subject.common_name != node.domain.full
        log :updating, "cert for node '#{node.name}' because domain.full has changed"
        return true
      end
      cert.openssl_body.extensions.each do |ext|
        #
        # TODO: currently this only works with a single IP or DNS.
        #
        if ext.oid == "subjectAltName"
          ips = []
          dns_names = []
          ext.value.split(",").each do |value|
            value.strip!
            ips << $1          if value =~ /^IP Address:(.*)$/
            dns_names << $1    if value =~ /^DNS:(.*)$/
          end
          if ips.first != node.ip_address
            log :updating, "cert for node '#{node.name}' because ip_address has changed (from #{ips} to #{node.ip_address})"
            return true
          elsif dns_names != dns_names_for_node(node)
            log :updating, "cert for node '#{node.name}' because domain name aliases have changed (from #{dns_names.inspect} to #{dns_names_for_node(node).inspect})"
            return true
          end
        end
      end
    end
    return false
  end

  def generate_cert_for_node(node)
    return if node.x509.use == false

    cert = CertificateAuthority::Certificate.new

    # set subject
    cert.subject.common_name = node.domain.full
    cert.serial_number.number = cert_serial_number(node.domain.full)

    # set expiration
    cert.not_before = today
    cert.not_after = years_from_today(manager.provider.ca.server_certificates.life_span.to_i)

    # generate key
    cert.key_material.generate_key(manager.provider.ca.server_certificates.bit_size)

    # sign
    cert.parent = ca_root
    cert.sign!(server_signing_profile(node))

    # save
    write_file!([:node_x509_key, node.name], cert.key_material.private_key.to_pem)
    write_file!([:node_x509_cert, node.name], cert.to_pem)
  end

  def generate_test_client_cert
    cert = CertificateAuthority::Certificate.new
    cert.serial_number.number = cert_serial_number(manager.provider.domain)
    cert.subject.common_name = random_common_name(manager.provider.domain)
    cert.not_before = today
    cert.not_after  = years_from_today(1)
    cert.key_material.generate_key(1024) # just for testing, remember!
    cert.parent = ca_root
    cert.sign! client_test_signing_profile
    write_file! :test_client_key, cert.key_material.private_key.to_pem
    write_file! :test_client_cert, cert.to_pem
  end

  def ca_root
    @ca_root ||= begin
      load_certificate_file(:ca_cert, :ca_key)
    end
  end

  def load_certificate_file(crt_file, key_file=nil, password=nil)
    crt = read_file!(crt_file)
    openssl_cert = OpenSSL::X509::Certificate.new(crt)
    cert = CertificateAuthority::Certificate.from_openssl(openssl_cert)
    if key_file
      key = read_file!(key_file)
      cert.key_material.private_key = OpenSSL::PKey::RSA.new(key, password)
    end
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
  # digest options: SHA512, SHA256, SHA1
  #
  def server_signing_profile(node)
    {
      "digest" => manager.provider.ca.server_certificates.digest,
      "extensions" => {
        "keyUsage" => {
          "usage" => ["digitalSignature", "keyAgreement"]
        },
        "extendedKeyUsage" => {
          "usage" => ["serverAuth"]
        },
        "subjectAltName" => {
          "ips" => [node.ip_address],
          "dns_names" => dns_names_for_node(node)
        }
      }
    }
  end

  #
  # This is used when signing the main cert for the provider's domain
  # with our own CA (for testing purposes). Typically, this cert would
  # be purchased from a commercial CA, and not signed this way.
  #
  def domain_test_signing_profile
    {
      "digest" => "SHA256",
      "extensions" => {
        "keyUsage" => {
          "usage" => ["digitalSignature", "keyAgreement"]
        },
        "extendedKeyUsage" => {
          "usage" => ["serverAuth"]
        }
      }
    }
  end

  #
  # This is used when signing a dummy client certificate that is only to be
  # used for testing.
  #
  def client_test_signing_profile
    {
      "digest" => "SHA256",
      "extensions" => {
        "keyUsage" => {
          "usage" => ["digitalSignature", "keyAgreement"]
        },
        "extendedKeyUsage" => {
          "usage" => ["clientAuth"]
        }
      }
    }
  end

  def dns_names_for_node(node)
    names = [node.domain.internal]
    if node['dns'] && node.dns['aliases'] && node.dns.aliases.any?
      names += node.dns.aliases
      names.compact!
    end
    names.delete(node.domain.full) # already set to common name
    return names
  end

  #
  # For cert serial numbers, we need a non-colliding number less than 160 bits.
  # md5 will do nicely, since there is no need for a secure hash, just a short one.
  # (md5 is 128 bits)
  #
  def cert_serial_number(domain_name)
    Digest::MD5.hexdigest("#{domain_name} -- #{Time.now}").to_i(16)
  end

  #
  # for the random common name, we need a text string that will be unique across all certs.
  # ruby 1.8 doesn't have a built-in uuid generator, or we would use SecureRandom.uuid
  #
  def random_common_name(domain_name)
    cert_serial_number(domain_name).to_s(36)
  end

  def today
    t = Time.now
    Time.utc t.year, t.month, t.day
  end

  def years_from_today(num)
    t = Time.now
    Time.utc t.year + num, t.month, t.day
  end

  def months_from_today(num)
    date = Date.today >> num  # >> is months in the future operator
    Time.utc date.year, date.month, date.day
  end

end; end
