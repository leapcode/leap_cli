module LeapCli; module Commands

  desc 'Run tests.'
  command :test do |test|
    test.desc 'Creates files needed to run tests.'
    test.command :init do |init|
      init.action do |global_options,options,args|
        generate_test_client_openvpn_configs
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

  #
  # generates a whole bunch of openvpn configs that can be used to connect to different openvpn gateways
  #
  def generate_test_client_openvpn_configs
    assert_config! 'provider.ca.client_certificates.unlimited_prefix'
    assert_config! 'provider.ca.client_certificates.limited_prefix'
    template = read_file! Path.find_file(:test_client_openvpn_template)
    ['production', 'testing', 'local', 'development', nil].each do |env|
      vpn_nodes = manager.nodes[:environment => env][:services => 'openvpn']['openvpn.allow_limited' => true]
      if vpn_nodes.any?
        generate_test_client_cert(provider.ca.client_certificates.limited_prefix) do |key, cert|
          write_file! [:test_openvpn_config, [env, 'limited'].compact.join('_')], Util.erb_eval(template, binding)
        end
      end
      vpn_nodes = manager.nodes[:environment => env][:services => 'openvpn']['openvpn.allow_unlimited' => true]
      if vpn_nodes.any?
        generate_test_client_cert(provider.ca.client_certificates.unlimited_prefix) do |key, cert|
          write_file! [:test_openvpn_config, [env, 'unlimited'].compact.join('_')], Util.erb_eval(template, binding)
        end
      end
    end
  end

end; end
