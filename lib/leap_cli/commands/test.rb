module LeapCli; module Commands

  desc 'Run tests'
  command :test do |c|
    c.desc 'Creates files needed to run tests'
    c.command :init do |c|
      c.action do |global_options,options,args|
        generate_test_client_cert
        generate_test_client_openvpn_config
      end
    end

    c.desc 'Run tests'
    c.command :run do |c|
      c.action do |global_options,options,args|
        log 'not yet implemented'
      end
    end

    c.default_command :run
  end

  private

  def generate_test_client_openvpn_config
    template = read_file! Path.find_file(:test_client_openvpn_template)
    config = Util.erb_eval(template, binding)
    write_file! :test_client_openvpn_config, config
  end

end; end
