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
      assert_config! 'provider.ca.server_certificates.life_span'
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
          write_file!(:dh_params, output)
        else
          log 0, 'Generating DH parameters (takes a REALLY long time)...'
          output = OpenSSL::PKey::DH.generate(3248).to_pem
          write_file!(:dh_params, output)
        end
      end
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
          ext.value.match /IP Address:(.*?)(,|$)/
          ip = $1
          ext.value.match /DNS:(.*?)(,|$)/
          dns = $1
          if ip != node.ip_address
            log :updating, "cert for node '#{node.name}' because ip_address has changed"
            return true
          elsif dns != node.domain.internal
            log :updating, "cert for node '#{node.name}' because domain.internal has changed"
            return true
          end
        end
      end
    end
    return false
  end

  def generate_cert_for_node(node)
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
  # digest options: SHA512, SHA1
  #
  def server_signing_profile(node)
    {
      "digest" => "SHA256",
      "extensions" => {
        "keyUsage" => {
          "usage" => ["digitalSignature", "keyAgreement"]
        },
        "extendedKeyUsage" => {
          "usage" => ["serverAuth"]
        },
        "subjectAltName" => {
          "ips" => [node.ip_address],
          "dns_names" => [node.domain.internal]
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
