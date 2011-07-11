require 'json'
require 'bpm/version'

module BPM

  class Project < Package

    DEFAULT_CONFIG_PATH = File.expand_path('../default.json', __FILE__)
    DEFAULT_CONFIG = JSON.load File.read(DEFAULT_CONFIG_PATH)
    BPM_DIR = '.bpm'

    def self.project_file_path(path)
      Dir[File.join(path, '*.json')].find{|p| is_project_json?(p) }
    end

    def self.is_project_json?(path)
      json = JSON.load(File.read(path)) rescue nil
      return !!(json && json["bpm"])
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

    attr_reader :name

    def initialize(root_path, name=nil)
      super root_path

      if !name
        # If no name, try to find project json and get name from it
        project_file = self.class.project_file_path(root_path)
        name = File.basename(project_file, '.json') if project_file
      end

      @name = name || File.basename(root_path)
      @json_path = File.join(root_path, "#{@name}.json")

      load_json && validate
    end

    def bpm
      @bpm || BPM::VERSION
    end

    def all_dependencies
      dependencies.merge(dependencies_development)
    end

    def local_package_root(package_name=nil)
      File.join([@root_path, 'packages', package_name].compact)
    end

    def internal_package_root(package_name=nil)
      File.join([@root_path, BPM_DIR, 'packages', package_name].compact)
    end


    # Add a new dependency
    #
    # Adds to the project json and installs dependency

    def add_dependencies(new_deps, development=false, verbose=false)
      old_deps  = build_local_dependency_list(false) || []
      hard_deps = (development ? dependencies_development : dependencies).merge(new_deps)
      all_hard_deps = all_dependencies.merge(new_deps)
      exp_deps = find_non_local_dependencies(hard_deps, true)
      core_fetch_dependencies(exp_deps, (development ? :development : :runtime), verbose)

      if development
        self.dependencies_development = hard_deps
      else
        self.dependencies = hard_deps
      end
      rebuild_dependency_list(all_hard_deps, verbose)

      local_deps.each do |dep|
        next if old_deps.find { |pkg| (pkg.name == dep.name) && (pkg.version == dep.version) }
        puts "Added #{development ? "development " : ""}package '#{dep.name}' (#{dep.version})"
      end

      save!
    end


    # Remove a dependency
    #
    # Remove dependency from json. Does not remove from system.

    def remove_dependencies(package_names, verbose=false)

      hard_deps = dependencies.dup
      old_deps = build_local_dependency_list(false)

      package_names.each do |pkg_name|
        raise "'#{pkg_name}' is not a dependency" if hard_deps[pkg_name].nil?
        hard_deps.delete pkg_name
      end

      @dependencies = hard_deps
      rebuild_dependency_list hard_deps, verbose

      old_deps.each do |dep|
        next if local_deps.find { |pkg| (pkg.name == dep.name) && (pkg.version == dep.version) }
        puts "Removed package '#{dep.name}' (#{dep.version})"
      end

      save!

    end


    # Save to json

    def save!
      @had_changes = false
      File.open @json_path, 'w+' do |fd|
        fd.write JSON.pretty_generate as_json
      end
    end


    # Get dependencies from server if not installed

    def fetch_dependencies(verbose=false)
      exp_deps = find_non_local_dependencies(dependencies, true)
      return false unless core_fetch_dependencies(exp_deps, :runtime, verbose)
      exp_deps = find_non_local_dependencies(dependencies_development, true)
      core_fetch_dependencies(exp_deps, :development, verbose)
    end


    # Builds assets directory for dependent packages

    def build(mode=:debug, verbose=false)
      puts "Building static assets..." if verbose
      pipeline = BPM::Pipeline.new self, mode
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


    # Find package with name

    def package_from_name(package_name)
      return self if package_name == self.name
      local_deps.find { |pkg| pkg.name == package_name }
    end


    # Returns the path on disk to reach a given package name

    def path_from_package(package_name)
      ret = package_from_name package_name
      ret && ret.root_path
    end


    # Returns the path on disk for a given module id (relative to the project)

    def path_from_module(module_path)
      path_parts   = module_path.to_s.split '/'
      package_name = path_parts.shift
      module_path = path_from_package(package_name)

      if module_path
        # expand package_name => package_name/main
        path_parts = ['main'] if path_parts.size == 0

        # expand package_name/~dirname => package_name/mapped_dirname
        dirname = (path_parts.first && path_parts.first =~ /^~/) ?
                    path_parts.shift[1..-1] : 'lib'

        pkg = BPM::Package.new(module_path)
        pkg.load_json
        dirname = (pkg && pkg.directories[dirname]) || dirname

        # join the rest of the path
        module_path = [package_name, dirname, *path_parts] * '/'
      end

      module_path
    end


    # Returns the package object and module id for the path. Path must match
    # a package known to the project.

    def package_and_module_from_path(path)
      path = File.expand_path path.to_s
      pkg = local_deps.find {|cur| path =~ /^#{Regexp.escape cur.root_path.to_s}\//}
      pkg = self if pkg.nil? && path =~ /^#{Regexp.escape root_path.to_s}/
      raise "#{path} is not within a known package" if pkg.nil?

      dir_name = nil
      pkg.directories.each do |dname, dpath|
        dpaths = Array(dpath).map{|d| File.expand_path(d, pkg.root_path) }
        dpaths.each do |d|
          # Find a match and see if we can replace
          if path.gsub!(/^#{Regexp.escape(d)}\//, "#{dname}/")
            dir_name = dname
            break
          end
        end
        break if dir_name
      end

      if dir_name
        parts = path.split("/")
      else
        parts = Pathname.new(path).relative_path_from(Pathname.new(pkg.root_path)).to_s.split("/")
        dir_name = parts.first
      end

      if dir_name == 'lib'
        parts.shift
      else
        parts[0] = "~#{dir_name}"
      end

      parts[parts.size-1] = File.basename(parts.last, '.*')
      [pkg, parts.join('/')]
    end


    # List local dependency names, rebuilds list first time

    def local_deps
      @local_deps ||= build_local_dependency_list
    end

    # List of local dependency names in order of dependency

    def sorted_deps
      local_deps.inject([]){|ret, dep| add_sorted_dep(dep, local_deps, :both, ret); ret }
    end

    def sorted_runtime_deps
      local_deps.inject([]){|ret, dep| add_sorted_dep(dep, local_deps, :runtime, ret); ret }
    end

    def sorted_development_deps
      local_deps.inject([]){|ret, dep| add_sorted_dep(dep, local_deps, :development, ret); ret }
    end


    # Verifies that packages are available to meet all the dependencies

    def rebuild_dependency_list(deps=nil, verbose=false)
      puts "Selecting local dependencies..." if verbose

      found = find_dependencies(deps, verbose)

      install_root = self.internal_package_root
      FileUtils.rm_r install_root if File.exists? install_root
      FileUtils.mkdir_p install_root

      found.each do |pkg|
        dst_path = File.join(install_root, pkg.name)
        FileUtils.ln_s pkg.root_path, dst_path
      end

      @local_deps = nil
    end


    # Hash for conversion to json

    def as_json
      json = super
      json["bpm"] = self.bpm
      json
    end


    # Name of minifier

    def minifier_name
      pipeline && pipeline['minifier']
    end

    def load_json
      return super if has_json?
      FIELDS.keys.each{|f| send("#{c2u(f)}=", DEFAULT_CONFIG[f]) }
      self.name = File.basename(@json_path, '.json')
      self.version = "0.0.1"
      true
    end


  private

    # Make sure fields are set up properly

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

    def find_non_local_dependencies(deps, verbose)
      search_list = Array(deps)
      seen = []
      ret = {}

      until search_list.empty?
        name, version = search_list.shift
        next if seen.include?(name)
        seen << name

        package_root = local_package_root(name)
        if File.exists?(package_root)
          pkg = BPM::Package.new(package_root)
          pkg.load_json

          unless satisfied_by?(version, pkg.version)
            raise "Local package '#{pkg.name}' (#{pkg.version}) is not compatible with required version #{version}"
          end

          puts "~ Using local package '#{pkg.name}' (#{pkg.version})" if verbose

          search_list += Array(pkg.dependencies)
        else
          ret[name] = version
        end
      end

      ret
    end


    # Fetch any dependencies into local cache for the passed set of deps

    def core_fetch_dependencies(deps, type, verbose)
      puts "Fetching packages from remote..." if verbose
      deps.each do |pkg_name, pkg_version|
        core_fetch_dependency pkg_name, pkg_version, type, verbose
      end
    end


    # Fetch a single dependency into local cache

    def core_fetch_dependency(package_name, vers, type, verbose)
      prerelease = false
      if vers == '>= 0-pre'
        prerelease = true
        vers = '>= 0'
      else
        prerelease = vers =~ /[a-zA-Z]/
      end

      dep = LibGems::Dependency.new(package_name, vers, type)
      cur_installed = LibGems.source_index.search(dep)

      begin
        installed = BPM::Remote.new.install(package_name, vers, prerelease)
      rescue LibGems::GemNotFoundException
        # If we have it locally but not remote, that's ok
        installed = []
      end

      cur_installed.each do |ci|
        installed.reject! { |i| ci.name == i.name && ci.version == i.version }
      end

      installed.each do |i|
        puts "Fetched #{i.name} (#{i.version}) from remote" if verbose
      end

    end


    # Get list of local dep names from the .bpm directory
    #
    # Pass +false+ to prevent the list from being rebuilt

    def build_local_dependency_list(force=true)
      install_root = self.internal_package_root

      unless File.exists?(install_root)
        return nil unless force
        rebuild_dependency_list
      end

      Dir[File.join(install_root, '*')].map do |package_name|
        pkg = BPM::Package.new package_name
        pkg.load_json
        pkg
      end
    end

    # Tell if package is vendored

    def has_local_package?(package_name)
      File.exists?(local_package_root(package_name))
    end


    # Tell if given version is satisfied by the passed version

    def satisfied_by?(req_vers, new_vers)
      req = LibGems::Requirement.new(req_vers)
      req_vers.sub(/^= /,'') == new_vers.sub(/^= /,'') ||
      req.satisfied_by?(LibGems::Version.new(new_vers))
    end


    # Get list of dependencies, raising if not found or conflicting

    def find_dependencies(deps=nil, verbose=false)
      deps ||= all_dependencies

      search_list = Array(deps)
      found = []
      ret = []

      until search_list.empty?
        name, version = search_list.shift

        if dup = found.find{|p| p.name == name}
          # already found, check for conflicts
          next if satisfied_by?(version, dup.version)
          raise PackageConflictError.new(name, dup.version, version)
        end

        pkg = locate_package(name, version, verbose)
        raise PackageNotFoundError.new(name, version) unless pkg

        found << pkg

        # Look up dependencies of dependencies
        search_list += Array(pkg.dependencies)

        ret << pkg
      end

      ret
    end


    # Find package locally or in global cache

    def locate_package(package_name, vers, verbose)
      local = has_local_package?(package_name)
      # It's true that we don't have a prerelase check here, but the
      # previous one we had didn't do anything, so it's better to have
      # none than one that doesn't work
      vers = ">= 0" if vers == ">= 0-pre"
      src_path = local ?
        local_package_root(package_name) :
        BPM::Local.new.source_root(package_name, vers)

      return nil unless src_path

      pkg = BPM::Package.new(src_path)
      pkg.load_json

      puts "~ Using #{local ? "local" : "fetched"} package '#{pkg.name}' (#{pkg.version})" if verbose

      pkg
    end


    # Method for help in sorting dependencies

    def add_sorted_dep(dep, deps, type, sorted)
      return if sorted.include? dep
      list = {}
      list.merge!(dep.dependencies) if [:both, :runtime].include?(type)
      list.merge!(dep.dependencies_development) if [:both, :development].include?(type)
      list.each do |dep_name, dep_vers|
        found_dep = deps.find { |cur| cur.name == dep_name }
        add_sorted_dep(found_dep, deps, type, sorted) if found_dep
      end
      sorted << dep unless sorted.include? dep
    end

  end

end
