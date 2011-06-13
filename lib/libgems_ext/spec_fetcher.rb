require 'libgems/spec_fetcher'

module LibGems
  class SpecFetcher
    alias :orig_initialize :initialize
    def initialize(*args)
      orig_initialize(*args)
      @dir = File.join LibGems.dir, 'specs'
    end
  end
end
