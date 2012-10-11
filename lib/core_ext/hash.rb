#
#
# We modify Hash to add a few features we need:
#
# * sorted output of keys to in yaml.
# * reference values either with hsh[key] or hsh.key
# * deep merge
# * select fields
#
# Because the json parsing code we use doesn't support setting a custom class, it is easier for us to just modify Hash.
#

require 'yaml'

class Hash

  ##
  ## YAML
  ##

  #
  # make the type appear to be a normal Hash in yaml, even for subclasses.
  #
  def to_yaml_type
   "!map"
  end

  #
  # just like Hash#to_yaml, but sorted
  #
  def to_yaml(opts = {})
    YAML::quick_emit(self, opts) do |out|
      out.map(taguri, to_yaml_style) do |map|
        keys.sort.each do |k|
          v = self[k]
          map.add(k, v)
        end
      end
    end
  end

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

end
