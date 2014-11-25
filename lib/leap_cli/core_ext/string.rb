#
# make ruby 1.9 act more like ruby 1.8
#
unless String.method_defined?(:to_a)
  class String
    def to_a; [self]; end
  end
end

unless String.method_defined?(:any?)
  class String
    def any?; self.chars.any?; end
  end
end
