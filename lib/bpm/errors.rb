module BPM

  class Error < StandardError
    
    def format_message(*args)
      args.join ","
    end
    
    def initialize(*args)
      super format_message(*args)
    end
  end
    
  class InvalidPackageError < BPM::Error
    def format_message(package, msg=nil)
      msg = msg.nil? ? '' : ": #{msg}"
      "There was a problem parsing #{File.basename(package.json_path)}#{msg}"
    end
  end
  
  class PackageNotFoundError < BPM::Error
    def format_message(name, version)
      "Could not find eligible package for '#{name}' (#{version})"
    end
  end

  class MinifierNotFoundError < PackageNotFoundError
    def format_message(minifier_name)
      "Minifier package #{minifier_name} was not found.  Try running bpm update to refresh."
    end
  end
  
  class PackageConflictError < BPM::Error
    def format_message(name, version_a, version_b)
      "Conflicting requirement for '#{name}' (requires #{version_a} and #{version_b})"
    end
  end
  
  class LocalPackageConflictError < PackageConflictError
    def format_message(name, version_a, version_b)
      "Local package '#{name}' (#{version_b}) is not compatible with required version #{version_a}"
    end
  end
  
end
