class Hash

  ##
  ## CONVERTING
  ##

  #
  # convert self into a hash, but only include the specified keys
  #
  def pick(*keys)
    keys.map(&:to_s).inject({}) do |hsh, key|
      if has_key?(key)
        hsh[key] = self[key]
      end
      hsh
    end
  end

  #
  # recursive merging (aka deep merge)
  # taken from ActiveSupport::CoreExtensions::Hash::DeepMerge
  #
  def deep_merge(other_hash)
    self.merge(other_hash) do |key, oldval, newval|
      oldval = oldval.to_hash if oldval.respond_to?(:to_hash)
      newval = newval.to_hash if newval.respond_to?(:to_hash)
      oldval.class.to_s == 'Hash' && newval.class.to_s == 'Hash' ? oldval.deep_merge(newval) : newval
    end
  end

  def deep_merge!(other_hash)
    replace(deep_merge(other_hash))
  end

  #
  # A recursive symbolize_keys
  #
  unless Hash.method_defined?(:symbolize_keys)
    def symbolize_keys
      self.inject({}) {|result, (key, value)|
        new_key = case key
                  when String then key.to_sym
                  else key
                  end
        new_value = case value
                    when Hash then symbolize_keys(value)
                    else value
                    end
        result[new_key] = new_value
        result
      }
    end
  end
end
