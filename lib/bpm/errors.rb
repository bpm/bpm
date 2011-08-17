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
      path = begin
        Pathname.new(package.json_path).relative_path_from(Pathname.new(Dir.pwd))
      rescue
        package.json_path
      end
      "There was a problem parsing #{path}#{msg}"
    end
  end
  
  class InvalidPackagePathError < BPM::InvalidPackageError
    def format_message(package)
      "Package at #{package.root_path} name and directory do not match. (name: #{package.name}).  Change the directory or package.json name to match."
    end
  end
  
  class PackageNotFoundError < BPM::Error
    def format_message(name, version)
      "Could not find eligible package for '#{name}' (#{version})"
    end
  end

  class MinifierNotFoundError < PackageNotFoundError
    def format_message(minifier_name)
      "Minifier package #{minifier_name} was not found.  Try running `bpm rebuild -u` to refresh."
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
  
  class TooManyTransportsError < BPM::Error
    def format_message(pkg)
      err = <<EOF
#{pkg.name} depends on #{pkg.provided_transports.size} packages that define transport plugins. Select a plugin by adding a `bpm:use:transport` property to the package.json
EOF
    end
  end
  
end
