module LeapCli
  module Commands

    def self.print_config_table(type, config_list)
      style = {:border_x => '-', :border_y => ':', :border_i => '-', :width => 60}

      if type == :services
        t = table do
          self.style = style
          self.headings = ['SERVICE', 'NODES']
          list = config_list.keys.sort
          list.each do |name|
            add_row [name, config_list[name].nodes.keys.join(', ')]
            add_separator unless name == list.last
          end
        end
        puts t
        puts "\n\n"
      elsif type == :tags
        t = table do
          self.style = style
          self.headings = ['TAG', 'NODES']
          list = config_list.keys.sort
          list.each do |name|
            add_row [name, config_list[name].nodes.keys.join(', ')]
            add_separator unless name == list.last
          end
        end
        puts t
        puts "\n\n"
      elsif type == :nodes
        t = table do
          self.style = style
          self.headings = ['NODE', 'SERVICES', 'TAGS']
          list = config_list.keys.sort
          list.each do |name|
            add_row [name, config_list[name].services.to_a.join(', '), config_list[name].tags.to_a.join(', ')]
            add_separator unless name == list.last
          end
        end
        puts t
      end
    end

    desc 'List nodes and their classifications'
    long_desc 'Prints out a listing of nodes, services, or tags.'
    arg_name 'filter'
    command :list do |c|
      c.action do |global_options,options,args|
        if args.any?
          print_config_table(:nodes, ConfigManager.filter(args))
        else
          print_config_table(:services, ConfigManager.services)
          print_config_table(:tags,     ConfigManager.tags)
          print_config_table(:nodes,  ConfigManager.nodes)
        end
      end
    end

  end
end
