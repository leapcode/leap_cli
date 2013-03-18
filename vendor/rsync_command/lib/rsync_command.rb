require "rsync_command/version"
require "rsync_command/ssh_options"
require "rsync_command/thread_pool"

require 'monitor'

class RsyncCommand
  attr_accessor :failures, :logger

  def initialize(options={})
    @options = options.dup
    @logger = @options.delete(:logger)
    @flags = @options.delete(:flags)
    @failures = []
    @failures.extend(MonitorMixin)
  end

  #
  # takes an Enumerable and iterates each item in the list in parallel.
  #
  def asynchronously(array, &block)
    pool = ThreadPool.new
    array.each do |item|
      pool.schedule(item, &block)
    end
    pool.shutdown
  end

  #
  # runs rsync, recording failures
  #
  def exec(src, dest, options={})
    @failures.synchronize do
      @failures.clear
    end
    rsync_cmd = command(src, dest, options)
    if options[:chdir]
      rsync_cmd = "cd '#{options[:chdir]}'; #{rsync_cmd}"
    end
    @logger.debug rsync_cmd if @logger
    ok = system(rsync_cmd)
    unless ok
      @failures.synchronize do
        @failures << {:source => src, :dest => dest, :options => options.dup}
      end
    end
  end

  #
  # returns true if last exec returned a failure
  #
  def failed?
    @failures && @failures.any?
  end

  #
  # build rsync command
  #
  def command(src, dest, options={})
    src = remote_address(src)
    dest = remote_address(dest)
    options = @options.merge(options)
    flags = []
    flags << @flags if @flags
    flags << options[:flags] if options.has_key?(:flags)
    flags << '--delete' if options[:delete]
    flags << includes(options[:includes]) if options.has_key?(:includes)
    flags << excludes(options[:excludes]) if options.has_key?(:excludes)
    flags << SshOptions.new(options[:ssh]).to_flags if options.has_key?(:ssh)
    "rsync #{flags.compact.join(' ')} #{src} #{dest}"
  end

  private

  #
  # Creates an rsync location if the +address+ is a hash with keys :user, :host, and :path
  # (each component is optional). If +address+ is a string, we just pass it through.
  #
  def remote_address(address)
    if address.is_a? String
      address # assume it is already formatted.
    elsif address.is_a? Hash
      [[address[:user], address[:host]].compact.join('@'), address[:path]].compact.join(':')
    end
  end

  def excludes(patterns)
    [patterns].flatten.compact.map { |p| "--exclude='#{p}'" }
  end

  def includes(patterns)
    [patterns].flatten.compact.map { |p| "--include='#{p}'" }
  end

end

