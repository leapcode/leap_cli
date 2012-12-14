module LeapCli; module Commands

  desc 'Prints information about a file or node.'
  arg_name '<file-or-node>', :optional => false
  command :inspect do |c|
    c.action do |global_options,options,args|
      object = args.first
      assert! object, 'A file path or node name is required'
      method = inspection_method(object)
      if method && defined?(method)
        self.send(method, object, options)
      else
        log "Sorry, I don't know how to inspect that."
      end
    end
  end

  private

  FTYPE_MAP = {
    "PEM certificate"         => :inspect_x509_cert,
    "PEM RSA private key"     => :inspect_x509_key,
    "OpenSSH RSA public key"  => :inspect_ssh_pub_key,
    "PEM certificate request" => :inspect_x509_csr
  }

  def inspection_method(object)
    if File.exists?(object)
      ftype = `file #{object}`.split(':').last.strip
      log 2, "file is of type '#{ftype}'"
      if FTYPE_MAP[ftype]
        FTYPE_MAP[ftype]
      elsif ftype == "ASCII text"
        nil
      end
    elsif manager.nodes[object]
      :inspect_node
    else
      nil
    end
  end

  def inspect_x509_key(file_path, options)
    assert_bin! 'openssl'
    puts assert_run! 'openssl rsa -in %s -text -check' % file_path
  end

  def inspect_x509_cert(file_path, options)
    assert_bin! 'openssl'
    puts assert_run! 'openssl x509 -in %s -text -noout' % file_path
    log 0, :"SHA256 fingerprint", X509.fingerprint("SHA256", file_path)
  end

  def inspect_x509_csr(file_path, options)
    assert_bin! 'openssl'
    puts assert_run! 'openssl req -text -noout -verify -in %s' % file_path
  end

  #def inspect_ssh_pub_key(file_path)
  #end

  def inspect_node(node_name, options)
    node = manager.nodes[node_name]
    puts node.dump_json
  end

end; end
