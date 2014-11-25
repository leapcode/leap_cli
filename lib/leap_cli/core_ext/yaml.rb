class Object
  #
  # ya2yaml will output hash keys in sorted order, but it outputs arrays
  # in natural order. This new method, sorted_ya2yaml(), is the same as
  # ya2yaml but ensures that arrays are sorted.
  #
  # This is important so that the .yaml files don't change each time you recompile.
  #
  # see https://github.com/afunai/ya2yaml/blob/master/lib/ya2yaml.rb
  #
  def sorted_ya2yaml(options = {})
    # modify array
    Array.class_eval do
      alias_method :collect_without_sort, :collect
      def collect(&block)
        sorted = sort {|a,b| a.to_s <=> b.to_s}
        sorted.collect_without_sort(&block)
      end
    end

    # generate yaml
    yaml_str = self.ya2yaml(options)

    # restore array
    Array.class_eval {alias_method :collect, :collect_without_sort}

    return yaml_str
  end
end
