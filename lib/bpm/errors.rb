module BPM

  class PackageNotFoundError < StandardError
    def initialize(name, version)
      super("Could not find eligible package for '#{name}' (#{version})")
    end
  end

  class PackageConflictError < StandardError
    def initialize(name, version_a, version_b)
      super("Conflicting requirement for '#{name}' (requires #{version_a} and #{version_b})")
    end
  end
  
end
