require 'libgems/uninstaller'

module BPM
  class Local < Repository
    def uninstall(package)
      LibGems::Uninstaller.new(package).uninstall
      true
    rescue LibGems::InstallError
      false
    end

    def pack(path, email=nil)
      package_path = File.dirname(File.expand_path path)
      cur_pwd = Dir.pwd

      FileUtils.cd package_path if package_path != cur_pwd
      package = BPM::Package.new(nil, :email => (email || creds.email), :standalone => true)
      package.json_path = File.basename path
      
      
      if package.valid?
        silence do
          LibGems::Builder.new(package.to_spec).build
        end
      end

      FileUtils.cd cur_pwd if package_path != cur_pwd
      package
    end

    def unpack(path, target)
      package = BPM::Package.new
      package.fill_from_gemspec(path)
      unpack_dir = File.expand_path(File.join(Dir.pwd, target, package.full_name))
      LibGems::Installer.new(path, :unpack => true).unpack unpack_dir
      package
    end

    def installed(packages)
      specs = LibGems.source_index.search dependency_for(packages)

      specs.map do |spec|
        [spec.name, spec.version, spec.original_platform]
      end
    end
    
    def preferred_version(package, vers)
      dep = LibGems::Dependency.new package, vers
      specs = LibGems.source_index.search dep
      specs.last.version.to_s
    end

    def source_root(package, vers)
      dep = LibGems::Dependency.new package, vers
      specs = LibGems.source_index.search dep
      spec = specs.last
      spec && File.join(spec.installation_path, 'gems', "#{spec.name}-#{spec.version}")
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

