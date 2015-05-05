unless Hash.method_defined?(:deep_dup)

  class Array
    def deep_dup
      map { |it| it.deep_dup }
    end
  end

  class Hash
    def deep_dup
      each_with_object(dup) do |(key, value), hash|
        hash[key.deep_dup] = value.deep_dup
      end
    end
  end

  class String
    def deep_dup
      self.dup
    end
  end

  class Integer
    def deep_dup
      self
    end
  end

  class Float
    def deep_dup
      self
    end
  end

  class TrueClass
    def deep_dup
      self
    end
  end

  class FalseClass
    def deep_dup
      self
    end
  end

  class NilClass
    def deep_dup
      self
    end
  end

end