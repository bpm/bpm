module BPM

  class PackageNotFoundError < StandardError
    def initialize(name, version)
      super("Could not find eligible package for '#{name}' (#{version})")
    end
  end

end
