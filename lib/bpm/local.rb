require 'libgems/uninstaller'

module BPM
  class Local < Repository
    def uninstall(package)
      LibGems::Uninstaller.new(package).uninstall
      true
    rescue LibGems::InstallError
      false
    end

    def pack(path)
      package = BPM::Package.new(nil, creds.email)
      package.json_path = path
      if package.valid?
        silence do
          LibGems::Builder.new(package.to_spec).build
        end
      end
      package
    end

    def unpack(path, target)
      package       = BPM::Package.new
      package.bpm = path
      unpack_dir    = File.expand_path(File.join(Dir.pwd, target, package.to_full_name))
      LibGems::Installer.new(path, :unpack => true).unpack unpack_dir
      package
    end

    def installed(packages)
      specs = LibGems.source_index.search dependency_for(packages)

      specs.map do |spec|
        [spec.name, spec.version, spec.original_platform]
      end
    end

    private

    def silence
      original_verbose = LibGems.configuration.verbose
      LibGems.configuration.verbose = false
      yield
    ensure
      LibGems.configuration.verbose = original_verbose
    end
  end
end

