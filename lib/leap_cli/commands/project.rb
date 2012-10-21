module LeapCli
  module Commands

    desc 'Creates a new provider directory.'
    arg_name '<directory>'
    skips_pre
    command :'new-provider' do |c|
      c.action do |global_options,options,args|
        directory = args.first
        unless directory && directory.any?
          help! "Directory name is required."
        end
        directory = File.expand_path(directory)
        if File.exists?(directory)
          raise "#{directory} already exists."
        end
        if agree("Create directory '#{directory}'? ")
          LeapCli.init(directory)
        else
          puts "OK, bye."
        end
      end
    end
  end
end