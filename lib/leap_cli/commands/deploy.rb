
module LeapCli
  module Commands

    DEFAULT_TAGS = ['leap_base','leap_service']

    desc 'Apply recipes to a node or set of nodes'
    long_desc 'The node-filter can be the name of a node, service, or tag.'
    arg_name 'node-filter'
    command :deploy do |c|

      # --fast
      c.switch :fast, :desc => 'Makes the deploy command faster by skipping some slow steps. A "fast" deploy can be used safely if you recently completed a normal deploy.',
                      :negatable => false

      # --tags
      c.flag :tags, :desc => 'Specify tags to pass through to puppet (overriding the default).',
                    :default_value => DEFAULT_TAGS.join(','), :arg_name => 'TAG[,TAG]'

      c.action do |global,options,args|
        init_submodules

        nodes = manager.filter!(args)
        if nodes.size > 1
          say "Deploying to these nodes: #{nodes.keys.join(', ')}"
          if !global[:yes] && !agree("Continue? ")
            quit! "OK. Bye."
          end
        end

        compile_hiera_files(nodes)

        ssh_connect(nodes) do |ssh|
          ssh.leap.log :checking, 'node' do
            ssh.leap.assert_initialized
          end

          ssh.leap.log :synching, "configuration files" do
            sync_hiera_config(ssh)
            sync_support_files(ssh)
          end

          # sync puppet manifests and apply them
          ssh.set :puppet_source, [Path.platform, 'puppet'].join('/')
          ssh.set :puppet_destination, '/srv/leap'

          # set tags
          if options[:tags]
            tags = options[:tags].split(',')
          else
            tags = DEFAULT_TAGS.dup
          end
          tags << 'leap_slow' unless options[:fast]

          ssh.set :puppet_command, "/usr/bin/puppet apply --color=false --tags=#{tags.join(',')}"
          ssh.set :puppet_lib, "puppet/modules"
          ssh.set :puppet_parameters, '--libdir puppet/lib --confdir puppet puppet/manifests/site.pp'
          ssh.set :puppet_stream_output, true
          ssh.apply_puppet
        end
      end
    end

    private

    def sync_hiera_config(ssh)
      dest_dir = provider.hiera_sync_destination
      ssh.leap.rsync_update do |server|
        node = manager.node(server.host)
        hiera_file = Path.relative_path([:hiera, node.name])
        ssh.leap.log hiera_file + ' -> ' + node.name + ':' + dest_dir + '/hiera.yaml'
        {:source => hiera_file, :dest => dest_dir + '/hiera.yaml'}
      end
    end

    def sync_support_files(ssh)
      dest_dir = provider.hiera_sync_destination
      ssh.leap.rsync_update do |server|
        node = manager.node(server.host)
        files_to_sync = node.file_paths.collect {|path| Path.relative_path(path, Path.provider) }
        if files_to_sync.any?
          ssh.leap.log(files_to_sync.join(', ') + ' -> ' + node.name + ':' + dest_dir)
          {
            :chdir => Path.provider,
            :source => ".",
            :dest => dest_dir,
            :excludes => "*",
            :includes => calculate_includes_from_files(files_to_sync),
            :flags => "--relative --dirs --delete --delete-excluded --filter='protect hiera.yaml' --copy-links"
          }
        else
          nil
        end
      end
    end

    def init_submodules
      Dir.chdir Path.platform do
        assert_run! "git submodule sync"
        statuses = assert_run! "git submodule status"
        statuses.strip.split("\n").each do |status_line|
          if status_line =~ /^[\+-]/
            submodule = status_line.split(' ')[1]
            log "Updating submodule #{submodule}"
            assert_run! "git submodule update --init #{submodule}"
          end
        end
      end
    end

    def calculate_includes_from_files(files)
      return nil unless files and files.any?

      # prepend '/' (kind of like ^ for rsync)
      includes = files.collect {|file| '/' + file}

      # include all sub files of specified directories
      includes.size.times do |i|
        if includes[i] =~ /\/$/
          includes << includes[i] + '**'
        end
      end

      # include all parent directories (required because of --exclude '*')
      includes.size.times do |i|
        path = File.dirname(includes[i])
        while(path != '/')
          includes << path unless includes.include?(path)
          path = File.dirname(path)
        end
      end

      return includes
    end

  end
end
