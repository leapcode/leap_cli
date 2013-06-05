module JSON
  #
  # Output JSON from ruby objects in such a manner that all the hashes and arrays are output in alphanumeric sorted order.
  # This is required so that our generated configs don't throw puppet or git for a tizzy fit.
  #
  # Beware: some hacky stuff ahead.
  #
  # This relies on the pure ruby implementation of JSON.generate (i.e. require 'json/pure')
  # see https://github.com/flori/json/blob/master/lib/json/pure/generator.rb
  #
  # The Oj way that we are not using: Oj.dump(obj, :mode => :compat, :indent => 2)
  #
  def self.sorted_generate(obj)
    # modify hash and array
    Hash.class_eval do
      alias_method :each_without_sort, :each
      def each(&block)
        keys.sort {|a,b| a.to_s <=> b.to_s }.each do |key|
          yield key, self[key]
        end
      end
    end
    Array.class_eval do
      alias_method :each_without_sort, :each
      def each(&block)
        sort {|a,b| a.to_s <=> b.to_s }.each_without_sort &block
      end
    end

    # generate json
    json_str = JSON.pretty_generate(obj)

    # restore hash and array
    Hash.class_eval  {alias_method :each, :each_without_sort}
    Array.class_eval {alias_method :each, :each_without_sort}

    return json_str
  end
end
