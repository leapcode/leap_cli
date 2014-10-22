#
# activesupport/lib/core_ext/object/to_json.rb overrides to_json for
# most core objects like so:
#
#    [Object, Array, FalseClass, Float, Hash, Integer, NilClass, String, TrueClass].each do |klass|
#      klass.class_eval do
#        # Dumps object in JSON (JavaScript Object Notation). See www.json.org for more info.
#        def to_json(options = nil)
#          ActiveSupport::JSON.encode(self, options)
#        end
#      end
#    end
#
# We cannot tolerate this. We need the normal to_json to be called, not
# ActiveSupport's custom version.
#
# This file exists to override the behavior of ActiveSupport. This file will get included
# instead of the normal to_json.rb.
#

