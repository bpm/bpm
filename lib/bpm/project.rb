require 'json'

module BPM

  class Project < Package

    DEFAULT_CONFIG_PATH = File.expand_path('../default.json', __FILE__)
    DEFAULT_CONFIG = JSON.load File.read(DEFAULT_CONFIG_PATH)
    BPM_DIR = '.bpm'

    def self.project_file_path(path)
      json_path = File.join path, "#{File.basename(path)}.json"
      json = JSON.load(File.read(json_path)) rescue nil
      return json && json["bpm"] && json_path
    end

    def self.is_project_root?(path)
      !!project_file_path(path) ||
      File.exists?(File.join(path, 'assets', 'bpm_packages.js'))
    end

    def self.nearest_project(path)
      path = File.expand_path path

      last = nil
      while path != last
        return new(path) if is_project_root?(path)
        last = path
        path = File.dirname path
      end
      nil
    end

    def initialize(root_path)
      super root_path
      @json_path = File.join root_path, "#{File.basename(root_path)}.json"
      load_json && validate
    end

    def add_dependencies(new_deps, verbose=false)

      old_deps  = build_local_deps(false) || []
      
      hard_deps = dependencies.dup
      new_deps.each { |pkg_name, pkg_vers| hard_deps[pkg_name] = pkg_vers }

      exp_deps = expand_local_packages hard_deps, true
      core_fetch_dependencies exp_deps, :runtime, true

      @dependencies = hard_deps
      rebuild_dependencies hard_deps, verbose
      
      local_deps.each do |dep|
        next if old_deps.find { |pkg| (pkg.name == dep.name) && (pkg.version == dep.version) }
        puts "Added package '#{dep.name}' (#{dep.version})"
      end

      save!
          
    end

    def remove_dependencies(package_names, verbose=false)

      hard_deps = dependencies.dup
      old_deps = build_local_deps false
      
      package_names.each do |pkg_name|
        raise "'#{pkg_name}' is not a dependency" if hard_deps[pkg_name].nil?
        hard_deps.delete pkg_name
      end

      @dependencies = hard_deps
      rebuild_dependencies hard_deps, verbose
      
      old_deps.each do |dep|
        next if local_deps.find { |pkg| (pkg.name == dep.name) && (pkg.version == dep.version) }
        puts "Removed package '#{dep.name}' (#{dep.version})"
      end
        
      save!
      
    end

    def save!
      @had_changes = false
      File.open @json_path, 'w+' do |fd|
        fd.write JSON.pretty_generate as_json
      end
    end
    
    def fetch_dependencies(verbose=false)
      core_fetch_dependencies(dependencies, :runtime, verbose)
    end

    # Builds assets directory for dependent packages
    def build(mode=:debug, verbose=false)
      puts "Building static assets..." if verbose
      pipeline = BPM::Pipeline.new self
      asset_root = File.join root_path, 'assets'

      pipeline.buildable_assets.each do |asset|
        dst_path = File.join asset_root, asset.logical_path
        FileUtils.mkdir_p File.dirname(dst_path)

        if asset.kind_of? Sprockets::StaticAsset
          puts "~ Copying #{asset.logical_path}" if verbose
          FileUtils.rm dst_path if File.exists? dst_path
          FileUtils.cp asset.pathname, dst_path
        else
          puts "~ Building #{asset.logical_path}" if verbose
          File.open(dst_path, 'w+') { |fd| fd << asset.to_s }
        end
      end
      
      puts "\n" if verbose
    end
      
    # Removes any built assets from the project.  Usually called before a
    # package is removed from the project to cleanup any assets
    def unbuild(verbose=false)
      
      puts "Removing stale assets..." if verbose
      
      pipeline = BPM::Pipeline.new self
      asset_root = File.join root_path, 'assets'
      pipeline.buildable_assets.each do |asset|
        next if asset.logical_path =~ /^bpm_/
        asset_path = File.join asset_root, asset.logical_path
        next unless File.exists? asset_path
        puts "~ Removing #{asset.logical_path}" if verbose
        FileUtils.rm asset_path
        
        # cleanup empty directories
        while !File.exists?(asset_path)
          asset_path = File.dirname asset_path
          FileUtils.rmdir(asset_path) if File.directory?(asset_path)
          if verbose && !File.exists?(asset_path) 
            puts "~ Removed empty directory #{File.basename asset_path}"
          end
        end
      end
      
      puts "\n" if verbose
    end
    
    # Returns the path on disk to reach a given package name
    def path_to_package(package_name)
      return root_path if package_name == self.name
      path = File.join(root_path, 'packages', package_name)
      File.exists?(path) ? path : nil
    end
    
    # Returns the path on disk for a given module id (relative to the project)
    def path_from_module(module_path)
      path_parts   = module_path.to_s.split '/'
      package_name = path_parts.shift
      module_path = path_to_package(package_name)
      if module_path
        # expand package_name => package_name/main
        path_parts = ['main'] if path_parts.size == 0
    
        # expand package_name/~dirname => package_name/mapped_dirname
        if path_parts.first && path_parts.first =~ /^~/
          dirname = path_parts.shift[1..-1]
        else
          dirname = 'lib'
        end
        pkg = BPM::Package.new(module_path)
        pkg.load_json
        dirname = (pkg && pkg.directories[dirname]) || dirname
    
        # join the rest of the path
        module_path = [package_name, dirname, *path_parts] * '/'
      end
      
      module_path
    end
    
    def local_deps(verbose=false)
      @local_deps ||= build_local_deps
    end


    # Verifies that packages are available to meet all the dependencies
    def rebuild_dependencies(deps=nil, verbose=false)
      
      puts "Selecting local dependencies..." if verbose
      
      found = locate_dependencies deps||dependencies, verbose

      install_root = File.join root_path, '.bpm', 'packages'
      FileUtils.rm_r install_root if File.exists? install_root
      FileUtils.mkdir_p install_root

      found.each do |pkg|
        dst_path = File.join install_root, pkg.name
        FileUtils.ln_s pkg.root_path, dst_path
      end
      
      @local_deps = nil
    end
    
  private

    def read
      if File.exists? @json_path
        super
      else
        @attributes = DEFAULT_CONFIG.dup
        @attributes["name"] = File.basename(@json_path, '.json')
        @attributes["version"] = "0.0.1"
      end
    end

    def validate_fields
      # TODO: Define other fields that are required for projects
      %w[name].all? do |field|
        value = send(field)
        if value.nil? || value.size.zero?
          add_error "Projects requires a '#{field}' field"
        else
          true
        end
      end
    end
    
    # builds a set of dependencies that excludes locally installed packages
    # and includes their dependencies instead.
    def expand_local_packages(deps, verbose)
      ret = {}
      
      todo = []
      seen = []
      
      deps.each { |pkg_name, pkg_version| todo << [pkg_name, pkg_version] }
      
      while todo.size > 0
        package_name, package_version = todo.shift
        next if seen.include? package_name
        seen << package_name
        
        package_root = File.join(@root_path, 'packages', package_name)
        
        if File.exists? package_root
          pkg = BPM::Package.new package_root
          pkg.load_json

          req = LibGems::Requirement.new(package_version)
          unless req.satisfied_by? LibGems::Version.new(pkg.version)
            raise "Local package '#{pkg.name}' (#{pkg.version}) is not compatible with required version #{package_version}"
          end
           
          puts "~ Using local package '#{pkg.name}' (#{pkg.version})" if verbose
          pkg.dependencies.each do |pkg_name, pkg_vers| 
            todo << [pkg_name, pkg_vers]
          end
          
        else
          ret[package_name] = package_version
        end
      end
      
      ret
    end
    
    # Fetch any dependencies into local cache for the passed set of deps
    def core_fetch_dependencies(deps, kind, verbose)
      puts "Fetching packages from remote..." if verbose
      deps.each do |pkg_name, pkg_version|
        core_fetch_dependency pkg_name, pkg_version, kind, verbose
      end
    end 
  
    def core_fetch_dependency(package_name, vers, kind, verbose)
      
      prerelease = false
      if vers == '>= 0-pre'
        prerelease = true
        vers = '>= 0'
      else
        prerelease = vers =~ /[a-zA-Z]/
      end

      dep = LibGems::Dependency.new(package_name, vers, kind)
      cur_installed = LibGems.source_index.search(dep)
      
      installed = BPM::Remote.new.install(package_name, vers, prerelease)

      cur_installed.each do |ci|
        installed.reject! { |i| ci.name == i.name && ci.version == i.version }
      end

      installed.each do |i|
        puts "Fetched #{i.name} (#{i.version}) from remote" if verbose 
      end
      
    end

    def build_local_deps(force=true)
      install_root = File.join root_path, '.bpm', 'packages'
      unless File.exists? install_root
        return nil if !force
        rebuild_dependencies 
      end
      
      Dir[File.join(install_root, '*')].map do |package_name|
        pkg = BPM::Package.new package_name
        pkg.load_json
        pkg
      end
    end

    def has_local_package?(package_name)
      package_root = File.join @root_path, 'packages', package_name
      File.exists? package_root
    end

    def satisfied_by?(req_vers, new_vers)
      req = LibGems::Requirement.new req_vers
      req_vers.sub(/^= /,'') == new_vers.sub(/^= /,'') ||
      req.satisfied_by?(LibGems::Version.new(new_vers)) 
    end

    def clean_version(vers)
      if vers == '>= 0-pre'
        prerel = true
        vers   = '>= 0'
      else
        prerel = vers =~ /[a-zA-Z]/
      end
      [vers, prerel]
    end
    
    def locate_dependencies(deps, verbose)
      todo = []
      seen = []
      ret  = []
      
      deps.each { |package_name, vers| todo << [package_name, vers] }
      
      while todo.size > 0
        package_name, vers = todo.shift
        
        if seen.include? package_name

          # already seen - verify requirements are not in conflict
          pkg = ret.find { |p| p.name == package_name }
          unless satisfied_by? vers, pkg.version
            raise "Conflicting dependencies '#{package_name}' requires #{pkg.version} and #{vers}"
          end
          
          next
        end

        seen << package_name

        # Find locally installed or fetched package
        pkg = locate_package package_name, vers, verbose

        if pkg.nil?
          raise "Could not find eligable package for '#{package_name}' (#{vers})"
        end

        # Add dependencies for found package to list
        pkg.dependencies.each do |dep_name, dep_vers|
          todo << [dep_name, dep_vers]
        end
        
        ret << pkg
      end
      
      ret
    end
    
    def locate_package(package_name, vers, verbose)
      if has_local_package? package_name 
        src_path = File.join root_path, 'packages', package_name
        pkg = BPM::Package.new src_path
        pkg.load_json
        puts "~ Using local package '#{pkg.name}' (#{pkg.version})" if verbose
      else
        vers, prerel = clean_version vers
        src_path = BPM::Local.new.source_root package_name, vers, prerel
        if src_path
          pkg = BPM::Package.new src_path
          pkg.load_json
          puts "~ Using fetched package '#{pkg.name}' (#{pkg.version})" if verbose
        end
      end
      
      pkg
    end
    
  end

end
