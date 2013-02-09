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
      elsif File.extname(object) == ".json"
        full_path = File.expand_path(object, Dir.pwd)
        if path_match?(:node_config, full_path)
          :inspect_node
        elsif path_match?(:service_config, full_path)
          :inspect_service
        elsif path_match?(:tag_config, full_path)
          :inspect_tag
        elsif path_match?(:provider_config, full_path)
          :inspect_provider
        elsif path_match?(:common_config, full_path)
          :inspect_common
        end
      end
    elsif manager.nodes[object]
      :inspect_node
    elsif manager.services[object]
      :inspect_service
    elsif manager.tags[object]
      :inspect_tag
    elsif object == "common"
      :inspect_common
    elsif object == "provider"
      :inspect_provider
    else
      nil
    end
  end

  #
  # inspectors
  #

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

  def inspect_node(arg, options)
    inspect_json(arg, options) {|name| manager.nodes[name] }
  end

  def inspect_service(arg, options)
    inspect_json(arg, options) {|name| manager.services[name] }
  end

  def inspect_tag(arg, options)
    inspect_json(arg, options) {|name| manager.tags[name] }
  end

  def inspect_provider(arg, options)
    inspect_json(arg, options) {|name| manager.provider }
  end

  def inspect_common(arg, options)
    inspect_json(arg, options) {|name| manager.common }
  end

  #
  # helpers
  #

  def inspect_json(arg, options)
    name = File.basename(arg).sub(/\.json$/, '')
    config = yield name
    puts config.dump_json
  end

  def path_match?(path_symbol, path)
    Dir.glob(Path.named_path([path_symbol, '*'])).include?(path)
  end

end; end
