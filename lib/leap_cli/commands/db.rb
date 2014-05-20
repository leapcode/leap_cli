module LeapCli; module Commands

  desc 'Database commands.'
  command :db do |db|
    db.desc 'Destroy all the databases.'
    db.command :destroy do |destroy|
      destroy.action do |global_options,options,args|
        say 'You are about to permanently destroy all database data.'
        return unless agree("Continue? ")
        nodes = manager.nodes[:services => 'couchdb']
        ssh_connect(nodes, connect_options(options)) do |ssh|
          ssh.run('/etc/init.d/bigcouch stop && test ! -z "$(ls /opt/bigcouch/var/lib/ 2> /dev/null)" && rm -r /opt/bigcouch/var/lib/* && echo "db destroyed" || echo "db already destroyed"')
        end
      end
    end
  end

  private

end; end
