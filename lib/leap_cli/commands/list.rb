module LeapCli
  module Commands

    desc 'List nodes and their classifications'
    long_desc 'Prints out a listing of nodes, services, or tags.'
    arg_name 'filter'
    command :list do |c|
      c.flag 'print', :desc => 'What attributes to print (optional)'
      c.action do |global_options,options,args|
        if options['print']
          print_node_properties(manager.filter(args), options['print'])
        else
          if args.any?
            print_config_table(:nodes, manager.filter(args))
          else
            print_config_table(:services, manager.services)
            print_config_table(:tags, manager.tags)
            print_config_table(:nodes, manager.nodes)
          end
        end
      end
    end

    private

    def self.print_node_properties(nodes, properties)
      node_list = manager.nodes
      properties = properties.split(',')
      max_width = nodes.keys.inject(0) {|max,i| [i.size,max].max}
      nodes.keys.sort.each do |node_name|
        value = properties.collect{|prop| node_list[node_name][prop]}.join(', ')
        printf("%#{max_width}s   %s\n", node_name, value)
      end
    end

    def self.print_config_table(type, object_list)
      style = {:border_x => '-', :border_y => ':', :border_i => '-', :width => 60}

      if type == :services
        t = table do
          self.style = style
          self.headings = ['SERVICE', 'NODES']
          list = object_list.keys.sort
          list.each do |name|
            add_row [name, object_list[name].node_list.keys.join(', ')]
            add_separator unless name == list.last
          end
        end
        puts t
        puts "\n\n"
      elsif type == :tags
        t = table do
          self.style = style
          self.headings = ['TAG', 'NODES']
          list = object_list.keys.sort
          list.each do |name|
            add_row [name, object_list[name].node_list.keys.join(', ')]
            add_separator unless name == list.last
          end
        end
        puts t
        puts "\n\n"
      elsif type == :nodes
        t = table do
          self.style = style
          self.headings = ['NODE', 'SERVICES', 'TAGS']
          list = object_list.keys.sort
          list.each do |name|
            services = object_list[name]['services'] || []
            tags     = object_list[name]['tags'] || []
            add_row [name, services.to_a.join(', '), tags.to_a.join(', ')]
            add_separator unless name == list.last
          end
        end
        puts t
      end
    end

  end
end
