module LeapCli; module Commands

  desc 'Run tests.'
  command :test do |test|
    test.desc 'Creates files needed to run tests.'
    test.command :init do |init|
      init.action do |global_options,options,args|
        generate_test_client_cert
        generate_test_client_openvpn_config
      end
    end

    test.desc 'Run tests.'
    test.command :run do |run|
      run.action do |global_options,options,args|
        log 'not yet implemented'
      end
    end

    test.default_command :run
  end

  private

  def generate_test_client_openvpn_config
    template = read_file! Path.find_file(:test_client_openvpn_template)

    ['production', 'testing', 'local'].each do |tag|
      vpn_nodes = manager.nodes[:tags => tag][:services => 'openvpn']
      if vpn_nodes.any?
        config = Util.erb_eval(template, binding)
        write_file! ('test_openvpn_'+tag).to_sym, config
      end
    end
  end

end; end
