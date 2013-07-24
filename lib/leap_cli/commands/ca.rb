require 'openssl'
require 'certificate_authority'
require 'date'
require 'digest/md5'

module LeapCli; module Commands

  desc "Manage X.509 certificates"
  command :cert do |cert|

    cert.desc 'Creates two Certificate Authorities (one for validating servers and one for validating clients).'
    cert.long_desc 'See see what values are used in the generation of the certificates (like name and key size), run `leap inspect provider` and look for the "ca" property. To see the details of the created certs, run `leap inspect <file>`.'
    cert.command :ca do |ca|
      ca.action do |global_options,options,args|
        assert_config! 'provider.ca.name'
        generate_new_certificate_authority(:ca_key, :ca_cert, provider.ca.name)
        generate_new_certificate_authority(:client_ca_key, :client_ca_cert, provider.ca.name + ' (client certificates only!)')
      end
    end

    cert.desc 'Creates or renews a X.509 certificate/key pair for a single node or all nodes, but only if needed.'
    cert.long_desc 'This command will a generate new certificate for a node if some value in the node has changed ' +
                   'that is included in the certificate (like hostname or IP address), or if the old certificate will be expiring soon. ' +
                   'Sometimes, you might want to force the generation of a new certificate, ' +
                   'such as in the cases where you have changed a CA parameter for server certificates, like bit size or digest hash. ' +
                   'In this case, use --force. If <node-filter> is empty, this command will apply to all nodes.'
    cert.arg_name 'FILTER'
    cert.command :update do |update|
      update.switch 'force', :desc => 'Always generate new certificates', :negatable => false
      update.action do |global_options,options,args|
        assert_files_exist! :ca_cert, :ca_key, :msg => 'Run `leap cert ca` to create them'
        assert_config! 'provider.ca.server_certificates.bit_size'
        assert_config! 'provider.ca.server_certificates.digest'
        assert_config! 'provider.ca.server_certificates.life_span'
        assert_config! 'common.x509.use'

        nodes = manager.filter!(args)
        nodes.each_node do |node|
          if !node.x509.use
            remove_file!([:node_x509_key, node.name])
            remove_file!([:node_x509_cert, node.name])
          elsif options[:force] || cert_needs_updating?(node)
            generate_cert_for_node(node)
          end
        end
      end
    end

    cert.desc 'Creates a Diffie-Hellman parameter file.' # (needed for server-side of some TLS connections)
    cert.command :dh do |dh|
      dh.action do |global_options,options,args|
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
    cert.desc "Creates a CSR for use in buying a commercial X.509 certificate."
    cert.long_desc "Unless specified, the CSR is created for the provider's primary domain. The properties used for this CSR come from `provider.ca.server_certificates`."
    cert.command :csr do |csr|
      csr.flag 'domain', :arg_name => 'DOMAIN', :desc => 'Specify what domain to create the CSR for.'
      csr.action do |global_options,options,args|
        assert_config! 'provider.domain'
        assert_config! 'provider.name'
        assert_config! 'provider.default_language'
        assert_config! 'provider.ca.server_certificates.bit_size'
        assert_config! 'provider.ca.server_certificates.digest'
        domain = options[:domain] || provider.domain
        assert_files_missing! [:commercial_key, domain], [:commercial_csr, domain], :msg => 'If you really want to create a new key and CSR, remove these files first.'

        server_certificates = provider.ca.server_certificates

        # RSA key
        keypair = CertificateAuthority::MemoryKeyMaterial.new
        log :generating, "%s bit RSA key" % server_certificates.bit_size do
          keypair.generate_key(server_certificates.bit_size)
          write_file! [:commercial_key, domain], keypair.private_key.to_pem
        end

        # CSR
        dn  = CertificateAuthority::DistinguishedName.new
        csr = CertificateAuthority::SigningRequest.new
        dn.common_name  = domain
        dn.organization = provider.name[provider.default_language]
        dn.country      = server_certificates['country']   # optional
        dn.state        = server_certificates['state']     # optional
        dn.locality     = server_certificates['locality']  # optional

        log :generating, "CSR with commonName => '%s', organization => '%s'" % [dn.common_name, dn.organization] do
          csr.distinguished_name = dn
          csr.key_material = keypair
          csr.digest = server_certificates.digest
          request = csr.to_x509_csr
          write_file! [:commercial_csr, domain], csr.to_pem
        end

        # Sign using our own CA, for use in testing but hopefully not production.
        # It is not that commerical CAs are so secure, it is just that signing your own certs is
        # a total drag for the user because they must click through dire warnings.
        #if options[:sign]
          log :generating, "self-signed x509 server certificate for testing purposes" do
            cert = csr.to_cert
            cert.serial_number.number = cert_serial_number(domain)
            cert.not_before = yesterday
            cert.not_after  = years_from_yesterday(1)
            cert.parent = ca_root
            cert.sign! domain_test_signing_profile
            write_file! [:commercial_cert, domain], cert.to_pem
            log "please replace this file with the real certificate you get from a CA using #{Path.relative_path([:commercial_csr, domain])}"
          end
        #end

        # FAKE CA
        unless file_exists? :commercial_ca_cert
          log :using, "generated CA in place of commercial CA for testing purposes" do
            write_file! :commercial_ca_cert, read_file!(:ca_cert)
            log "please also replace this file with the CA cert from the commercial authority you use."
          end
        end
      end
    end
  end

  private

  def generate_new_certificate_authority(key_file, cert_file, common_name)
    assert_files_missing! key_file, cert_file
    assert_config! 'provider.ca.name'
    assert_config! 'provider.ca.bit_size'
    assert_config! 'provider.ca.life_span'

    root = CertificateAuthority::Certificate.new

    # set subject
    root.subject.common_name = common_name
    possible = ['country', 'state', 'locality', 'organization', 'organizational_unit', 'email_address']
    provider.ca.keys.each do |key|
      if possible.include?(key)
        root.subject.send(key + '=', provider.ca[key])
      end
    end

    # set expiration
    root.not_before = yesterday
    root.not_after = years_from_yesterday(provider.ca.life_span.to_i)

    # generate private key
    root.serial_number.number = 1
    root.key_material.generate_key(provider.ca.bit_size)

    # sign self
    root.signing_entity = true
    root.parent = root
    root.sign!(ca_root_signing_profile)

    # save
    write_file!(key_file, root.key_material.private_key.to_pem)
    write_file!(cert_file, root.to_pem)
  end

  #
  # returns true if the certs associated with +node+ need to be regenerated.
  #
  def cert_needs_updating?(node)
    if !file_exists?([:node_x509_cert, node.name], [:node_x509_key, node.name])
      return true
    else
      cert = load_certificate_file([:node_x509_cert, node.name])
      if cert.not_after < months_from_yesterday(1)
        log :updating, "cert for node '#{node.name}' because it will expire soon"
        return true
      end
      if cert.subject.common_name != node.domain.full
        log :updating, "cert for node '#{node.name}' because domain.full has changed"
        return true
      end
      cert.openssl_body.extensions.each do |ext|
        if ext.oid == "subjectAltName"
          ips = []
          dns_names = []
          ext.value.split(",").each do |value|
            value.strip!
            ips << $1          if value =~ /^IP Address:(.*)$/
            dns_names << $1    if value =~ /^DNS:(.*)$/
          end
          if ips.first != node.ip_address
            log :updating, "cert for node '#{node.name}' because ip_address has changed (from #{ips.first} to #{node.ip_address})"
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
    cert.not_before = yesterday
    cert.not_after = years_from_yesterday(provider.ca.server_certificates.life_span.to_i)

    # generate key
    cert.key_material.generate_key(provider.ca.server_certificates.bit_size)

    # sign
    cert.parent = ca_root
    cert.sign!(server_signing_profile(node))

    # save
    write_file!([:node_x509_key, node.name], cert.key_material.private_key.to_pem)
    write_file!([:node_x509_cert, node.name], cert.to_pem)
  end

  #
  # yields client key and cert suitable for testing
  #
  def generate_test_client_cert(prefix=nil)
    cert = CertificateAuthority::Certificate.new
    cert.serial_number.number = cert_serial_number(provider.domain)
    cert.subject.common_name = [prefix, random_common_name(provider.domain)].join
    cert.not_before = yesterday
    cert.not_after  = years_from_yesterday(1)
    cert.key_material.generate_key(1024) # just for testing, remember!
    cert.parent = client_ca_root
    cert.sign! client_test_signing_profile
    yield cert.key_material.private_key.to_pem, cert.to_pem
  end

  def ca_root
    @ca_root ||= begin
      load_certificate_file(:ca_cert, :ca_key)
    end
  end

  def client_ca_root
    @client_ca_root ||= begin
      load_certificate_file(:client_ca_cert, :client_ca_key)
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
  # For keyusage, openvpn server certs can have keyEncipherment or keyAgreement.
  # Web browsers seem to break without keyEncipherment.
  # For now, I am using digitalSignature + keyEncipherment
  #
  # * digitalSignature -- for (EC)DHE cipher suites
  #   "The digitalSignature bit is asserted when the subject public key is used
  #    with a digital signature mechanism to support security services other
  #    than certificate signing (bit 5), or CRL signing (bit 6). Digital
  #    signature mechanisms are often used for entity authentication and data
  #    origin authentication with integrity."
  #
  # * keyEncipherment  ==> for plain RSA cipher suites
  #   "The keyEncipherment bit is asserted when the subject public key is used for
  #    key transport. For example, when an RSA key is to be used for key management,
  #    then this bit is set."
  #
  # * keyAgreement     ==> for used with DH, not RSA.
  #   "The keyAgreement bit is asserted when the subject public key is used for key
  #    agreement. For example, when a Diffie-Hellman key is to be used for key
  #    management, then this bit is set."
  #
  # digest options: SHA512, SHA256, SHA1
  #
  def server_signing_profile(node)
    {
      "digest" => provider.ca.server_certificates.digest,
      "extensions" => {
        "keyUsage" => {
          "usage" => ["digitalSignature", "keyEncipherment"]
        },
        "extendedKeyUsage" => {
          "usage" => ["serverAuth", "clientAuth"]
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
          "usage" => ["digitalSignature", "keyEncipherment"]
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
          "usage" => ["digitalSignature"]
        },
        "extendedKeyUsage" => {
          "usage" => ["clientAuth"]
        }
      }
    }
  end

  def dns_names_for_node(node)
    names = [node.domain.internal, node.domain.full]
    if node['dns'] && node.dns['aliases'] && node.dns.aliases.any?
      names += node.dns.aliases
      names.compact!
    end
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

  ##
  ## TIME HELPERS
  ##
  ## note: we use 'yesterday' instead of 'today', because times are in UTC, and some people on the planet
  ## are behind UTC.
  ##

  def yesterday
    t = Time.now - 24*24*60
    Time.utc t.year, t.month, t.day
  end

  def years_from_yesterday(num)
    t = yesterday
    Time.utc t.year + num, t.month, t.day
  end

  def months_from_yesterday(num)
    t = yesterday
    date = Date.new t.year, t.month, t.day
    date = date >> num  # >> is months in the future operator
    Time.utc date.year, date.month, date.day
  end

end; end
