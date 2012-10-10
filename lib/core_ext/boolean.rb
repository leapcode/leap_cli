#
# make is_a?(Boolean) possible.
#

module Boolean
end

class TrueClass
  include Boolean
end

class FalseClass
  include Boolean
end