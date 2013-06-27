
module LeapCli
  module Commands

    desc "Compile generated files."
    command :compile do |c|
      c.desc 'Compiles node configuration files into hiera files used for deployment.'
      c.command :all do |all|
        all.action do |global_options,options,args|
          compile_hiera_files
        end
      end

      c.desc "Compile a DNS zone file for your provider."
      c.command :zone do |zone|
        zone.action do |global_options, options, args|
          compile_zone_file
        end
      end

      c.default_command :all
    end

    protected

    def compile_hiera_files(nodes=nil)
      # these must come first
      update_compiled_ssh_configs

      # export generated files
      manager.export_nodes(nodes)
      manager.export_secrets(nodes.nil?) # only do a "clean" export if we are examining all the nodes
    end

    def update_compiled_ssh_configs
      update_authorized_keys
      update_known_hosts
    end

    ##
    ## ZONE FILE
    ##

    def relative_hostname(fqdn)
      @domain_regexp ||= /\.?#{Regexp.escape(provider.domain)}$/
      fqdn.sub(@domain_regexp, '')
    end

    #
    # serial is any number less than 2^32 (4294967296)
    #
    def compile_zone_file
      f = $stdout

      f.puts ZONE_HEADER % [provider.domain, provider.domain, provider.domain]

      max_width = manager.nodes.values.inject(0) {|max, node| [max, relative_hostname(node.domain.full).length].max }
      put_line = lambda {|host, line| f.puts("%-#{max_width}s %s" % [host, line])}

      if provider['dns'] && provider.dns['nameservers']
        provider.dns.nameservers.each do |ns|
          put_line.call "", "IN NS #{ns}."
        end
      end

      manager.environments.each do |env|
        next if env == 'local'
        nodes = manager.nodes[:environment => env]
        next unless nodes.any?
        f.puts ENV_HEADER % (env.nil? ? 'default' : env)
        nodes.each_node do |node|
          if node.dns.public
            hostname = relative_hostname(node.domain.full)
            put_line.call relative_hostname(node.domain.full), "IN A      #{node.ip_address}"
          end
          if node['dns']['aliases']
            node['dns']['aliases'].each do |host_alias|
              if host_alias != node.domain.full
                put_line.call relative_hostname(host_alias), "IN CNAME  #{relative_hostname(node.domain.full)}"
              end
            end
          end
          if node.services.include? 'mx'
            put_line.call relative_hostname(node.domain.full_suffix), "IN MX 10  #{relative_hostname(node.domain.full)}"
          end
        end
      end
    end

    ENV_HEADER = %[
;;
;; ENVIRONMENT %s
;;

]

    ZONE_HEADER = %[
;;
;; BIND data file for %s
;;

$TTL 600

@ IN SOA %s. %s. (
  0000          ; serial
  7200          ; refresh (  24 hours)
  3600          ; retry   (   2 hours)
  1209600       ; expire  (1000 hours)
  600 )         ; minimum (   2 days)
;
]

  end
end