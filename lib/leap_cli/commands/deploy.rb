
module LeapCli
  module Commands

    desc 'Apply recipes to a node or set of nodes.'
    long_desc 'The FILTER can be the name of a node, service, or tag.'
    arg_name 'FILTER'
    command :deploy do |c|

      # --fast
      c.switch :fast, :desc => 'Makes the deploy command faster by skipping some slow steps. A "fast" deploy can be used safely if you recently completed a normal deploy.',
                      :negatable => false

      # --sync
      c.switch :sync, :desc => "Sync files, but don't actually apply recipes."

      # --force
      c.switch :force, :desc => 'Deploy even if there is a lockfile.', :negatable => false

      # --dev
      c.switch :dev, :desc => "Development mode: don't run 'git submodule update' before deploy.", :negatable => false

      # --tags
      c.flag :tags, :desc => 'Specify tags to pass through to puppet (overriding the default).',
                    :default_value => DEFAULT_TAGS.join(','), :arg_name => 'TAG[,TAG]'

      c.flag :port, :desc => 'Override the default SSH port.',
                    :arg_name => 'PORT'

      c.flag :ip,   :desc => 'Override the default SSH IP address.',
                    :arg_name => 'IPADDRESS'

      c.action do |global,options,args|

        if options[:dev] != true
          init_submodules
        end

        nodes = filter_deploy_nodes(args)
        if nodes.size > 1
          say "Deploying to these nodes: #{nodes.keys.join(', ')}"
          if !global[:yes] && !agree("Continue? ")
            quit! "OK. Bye."
          end
        end

        compile_hiera_files

        ssh_connect(nodes, connect_options(options)) do |ssh|
          ssh.leap.log :checking, 'node' do
            ssh.leap.check_for_no_deploy
            ssh.leap.assert_initialized
          end
          ssh.leap.log :synching, "configuration files" do
            sync_hiera_config(ssh)
            sync_support_files(ssh)
          end
          ssh.leap.log :synching, "puppet manifests" do
            sync_puppet_files(ssh)
          end
          unless options[:sync]
            ssh.leap.log :applying, "puppet" do
              ssh.puppet.apply(:verbosity => [LeapCli.log_level,5].min, :tags => tags(options), :force => options[:force])
            end
          end
        end

      end
    end

    private

    def sync_hiera_config(ssh)
      dest_dir = provider.hiera_sync_destination
      ssh.rsync.update do |server|
        node = manager.node(server.host)
        hiera_file = Path.relative_path([:hiera, node.name])
        ssh.leap.log hiera_file + ' -> ' + node.name + ':' + dest_dir + '/hiera.yaml'
        {
          :source => hiera_file,
          :dest => dest_dir + '/hiera.yaml',
          :flags => "-rltp --chmod=u+rX,go-rwx"
        }
      end
    end

    def sync_support_files(ssh)
      dest_dir = provider.hiera_sync_destination
      ssh.rsync.update do |server|
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
            :flags => "-rltp --chmod=u+rX,go-rwx --relative --delete --delete-excluded --filter='protect hiera.yaml' --copy-links"
          }
        else
          nil
        end
      end
    end

    def sync_puppet_files(ssh)
      ssh.rsync.update do |server|
        ssh.leap.log(Path.platform + '/[bin,tests,puppet] -> ' + server.host + ':' + LeapCli::PUPPET_DESTINATION)
        {
          :dest => LeapCli::PUPPET_DESTINATION,
          :source => '.',
          :chdir => Path.platform,
          :excludes => '*',
          :includes => ['/bin', '/bin/**', '/puppet', '/puppet/**', '/tests', '/tests/**'],
          :flags => "-rlt --relative --delete --copy-links"
        }
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

    def tags(options)
      if options[:tags]
        tags = options[:tags].split(',')
      else
        tags = LeapCli::DEFAULT_TAGS.dup
      end
      tags << 'leap_slow' unless options[:fast]
      tags.join(',')
    end

    #
    # for safety, we allow production deploys to be turned off in the Leapfile.
    #
    def filter_deploy_nodes(filter)
      nodes = manager.filter!(filter)
      if !leapfile.allow_production_deploy
        nodes = nodes[:environment => "!production"]
        assert! nodes.any?, "Skipping deploy because @allow_production_deploy is disabled."
      end
      nodes
    end

  end
end
