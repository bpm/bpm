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
      File.exists?(File.join(path, 'assets', 'bpm_libs.js'))
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
      else
        project_file = File.join root_path, "#{name}.json"
      end

      @name = name || File.basename(root_path)
      @json_path = project_file

      load_json && validate
    end

    def bpm
      @bpm || BPM::COMPAT_VERSION
    end

    def validate_name_and_path
      # do nothing. never an error
    end

    # Returns a fully normalized hash of build settings
    def build_settings(mode=:debug)
      ret = {}
      deps = mode == :debug ? sorted_deps : sorted_runtime_deps
      deps.each { |dep| merge_build_settings(ret, dep, mode) }
      merge_build_settings ret, self, mode, false
      ret
    end

    def all_dependencies
      deps = dependencies.merge(dependencies_development || {})
      deps.merge(dependencies_build)
    end

    def local_package_root(package_name=nil)
      File.join([@root_path, 'packages', package_name].compact)
    end

    def vendor_root(*paths)
      File.join @root_path, 'vendor', *paths
    end
    
    def internal_package_root(package_name=nil)
      File.join([@root_path, BPM_DIR, 'packages', package_name].compact)
    end

    def assets_root(*paths)
      File.join @root_path, 'assets', *paths
    end
    
    def preview_root(*paths)
      File.join @root_path, '.bpm', 'preview', *paths
    end
    
    def build_app?
      !!(bpm_build && bpm_build["bpm_libs.js"] && 
                      bpm_build["bpm_libs.js"]["directories"] && 
                      bpm_build["bpm_libs.js"]["directories"].size>0)
    end
    
    def build_app=(value)
      
      bpm_libs = "bpm_libs.js"
      bpm_styles = "bpm_styles.css"
      
      if value
        bpm_build[bpm_libs] ||= {}
        hash = bpm_build[bpm_libs]
        hash['directories'] ||= []
        hash['directories'] << 'lib' if hash['directories'].size==0
        hash['minifier']    ||= 'uglify-js'
        
        bpm_build[bpm_styles] ||= {}
        hash = bpm_build[bpm_styles]
        hash['directories'] ||= []
        hash['directories'] << 'css' if hash['directories'].size==0
        
        directories ||= {}
        directories['lib'] ||= ['app']
      else
        bpm_build[bpm_libs]['directories'] = []
        bpm_build[bpm_styles]['directories'] = []
      end
      value
    end
    
    # returns array of all assets that should be generated for this project
    def buildable_asset_filenames(mode)
      build_settings(mode).keys.reject { |x| !(x =~ /\..+$/) }
    end
    
    # Validates that all required files are present in the project needed
    # for compile to run.  This will not fetch new dependencies from remote.
    def verify_and_repair(mode=:debug, verbose=false)
      valid_deps = find_dependencies rescue nil
      fetch_dependencies(verbose) if valid_deps.nil?
      rebuild_dependency_list nil, verbose
      rebuild_preview verbose
    end
    
    def rebuild_preview(verbose=false)
      
      needs_rebuild = true
      
      if File.directory?(preview_root)
        cur_previews  = Dir[preview_root('**', '*')].sort.reject { |x| File.directory?(x) }
        exp_filenames = buildable_asset_filenames(:debug)
        exp_previews  = exp_filenames.map { |x| preview_root(x) }.sort
        needs_rebuild = cur_previews != exp_previews
      end
      
      if needs_rebuild
        FileUtils.rm_r preview_root if File.exists? preview_root
        buildable_asset_filenames(:debug).each do |filename|
          next if File.exists? preview_root(filename)
          FileUtils.mkdir_p File.dirname(preview_root(filename))
          FileUtils.touch preview_root(filename)
        end
      end
      
    end
    
    # Add a new dependency
    #
    # Adds to the project json and installs dependency
    
    def add_dependencies(new_deps, development=false, verbose=false)
      old_deps  = build_local_dependency_list(false) || []
      hard_deps = (development ? dependencies_development : dependencies).merge(new_deps)
      all_hard_deps = all_dependencies.merge(new_deps)
      exp_deps = find_non_local_dependencies(all_hard_deps, true)
      
      puts "Fetching packages from remote..." if verbose
      core_fetch_dependencies(exp_deps, verbose)
      
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
      puts "Fetching packages from remote..." if verbose
      exp_deps = find_non_local_dependencies(all_dependencies, true)
      core_fetch_dependencies(exp_deps, verbose)
    end


    # Builds assets directory for dependent packages

    def build(mode=:debug, verbose=false)
      
      verify_and_repair mode, verbose

      puts "Building static assets..." if verbose

      report_package_locations if verbose
      
      # Seed the project with any required files to ensure they are built
      buildable_asset_filenames(mode).each do |filename|
        dst_path = assets_root filename
        next if File.exists? dst_path
        FileUtils.mkdir_p File.dirname(dst_path)
        FileUtils.touch dst_path
      end
      
      pipeline = BPM::Pipeline.new self, mode
      pipeline.buildable_assets.each do |asset|
        dst_path = assets_root asset.logical_path
        FileUtils.mkdir_p File.dirname(dst_path)

        if asset.kind_of? Sprockets::StaticAsset
          puts "~ Copying #{asset.logical_path}" if verbose
          FileUtils.rm dst_path if File.exists? dst_path
          FileUtils.cp asset.pathname, dst_path
        else
          $stdout << "~ Building #{asset.logical_path}..." if verbose
          File.open(dst_path, 'w+') { |fd| fd << asset.to_s }
          if verbose
            gzip_size = `gzip -c #{dst_path}`.bytesize
            gzip_size = gzip_size < 1024 ? "#{gzip_size} bytes" : "#{gzip_size / 1024} Kb"
            $stdout << " (gzipped size: #{gzip_size})\n"
          end
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
      dep_names = (dependencies.keys + dependencies_development.keys).uniq
      ret       = []

      dep_names.each do |dep_name|
        dep = local_deps.find { |x| x.name == dep_name }
        add_sorted_dep(dep, local_deps, :both, ret)
      end
      ret
    end

    def sorted_runtime_deps
      
      dep_names = dependencies.map { |name, vers| name }
      deps = local_deps.reject { |dep| !dep_names.include?(dep.name) }
      
      deps.inject([]) do |ret, dep| 
        add_sorted_dep(dep, local_deps, :runtime, ret)
        ret
      end
      
    end

    def sorted_development_deps
      dep_names = dependencies_development.map { |name, vers| name }
      deps = local_deps.reject { |dep| !dep_names.include?(dep.name) }
      
      deps = deps.inject([]) do |ret, dep| 
        add_sorted_dep(dep, local_deps, :both, ret)
        ret
      end
      
      # development deps should include all dependencies of dev deps excluding
      # those that are bonafide runtime deps
      runtime_deps = sorted_runtime_deps
      deps.reject! { |pkg| runtime_deps.include?(pkg) }
      deps
    end


    # Verifies that packages are available to meet all the dependencies
    def rebuild_dependency_list(deps=nil, verbose=false)

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

    def minifier_name(asset_name)
      build_settings[asset_name] && build_settings[asset_name]['bpm:minifier']
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

        package_root = locate_local_package(name)
        if package_root
          pkg = BPM::Package.new(package_root)
          pkg.load_json

          unless satisfied_by?(version, pkg.version)
            raise LocalPackageConflictError.new(pkg.name, version, pkg.version)
          end

          search_list += Array(pkg.dependencies)
          search_list += Array(pkg.dependencies_development)
          search_list += Array(pkg.dependencies_build)
        else
          ret[name] = version
        end
      end

      ret
    end


    # Fetch any dependencies into local cache for the passed set of deps

    def core_fetch_dependencies(deps, verbose)
      deps.each do |pkg_name, pkg_version|
        core_fetch_dependency pkg_name, pkg_version, :runtime, verbose
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
        puts "~ Fetched #{i.name} (#{i.version}) from remote" if verbose
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
      !!locate_local_package(package_name)
    end


    # Tell if given version is satisfied by the passed version

    def satisfied_by?(req_vers, new_vers)
      req = LibGems::Requirement.new(req_vers)
      req_vers.sub(/^= /,'') == new_vers.sub(/^= /,'') ||
      req.satisfied_by?(LibGems::Version.new(new_vers))
    end


    # Get list of dependencies, searching only the project and fetched 
    # packages.  Does not query remote server.  Raises if not found or 
    # conflicting.
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
        search_list += Array(pkg.dependencies_development)
        search_list += Array(pkg.dependencies_build)

        ret << pkg
      end

      ret
    end


    def locate_local_package(package_name)
      src_path = local_package_root package_name
      unless File.directory?(src_path)
        src_path = Dir[vendor_root('*','packages','*')].find do |path|
          File.basename(path)==package_name && File.directory?(path)
        end
      end
      src_path
    end

    # Find package locally or in global cache

    def locate_package(package_name, vers, verbose)
      local = has_local_package?(package_name)
      
      # It's true that we don't have a prerelase check here, but the
      # previous one we had didn't do anything, so it's better to have
      # none than one that doesn't work
      vers = ">= 0" if vers == ">= 0-pre"
      src_path = local ? locate_local_package(package_name) :  
                         BPM::Local.new.source_root(package_name, vers)

      return nil unless src_path

      pkg = BPM::Package.new(src_path)
      pkg.load_json # throws exception if json invalid
      pkg
    end

    # pass in a hash of dependencies and versions
    def report_package_locations(deps=nil)
      deps ||= local_deps
      deps.each do |dep|
        is_local = has_local_package?(dep.name) ? 'local' : 'fetched'
        puts "~ Using #{is_local} package '#{dep.name}' (#{dep.version})"
      end
    end
      
    # Method for help in sorting dependencies

    def add_sorted_dep(dep, deps, type, sorted, seen=[])
      return if seen.include? dep
      seen << dep # we want to do this first to avoid cylical refs
      
      list = {}
      list.merge!(dep.dependencies) if [:both, :runtime].include?(type)
      list.merge!(dep.dependencies_development) if [:both, :development].include?(type)
      list.each do |dep_name, dep_vers|
        found_dep = deps.find { |cur| cur.name == dep_name }
        add_sorted_dep(found_dep, deps, type, sorted, seen) if found_dep
      end
      sorted << dep unless sorted.include? dep
    end
    
    def has_mode(opts, mode)
      return false if opts.nil?
      modes = Array(opts['modes'])
      modes.size==0 || modes.include?('*') || modes.include?(mode.to_s)
    end
    
    
    ## BUILD OPTIONS
    
    def merge_build_opts(ret, dep_name, target_name, opts, mode)
      
      ret[target_name] ||= {}
      
      if opts['assets']
        ret[target_name] = opts['assets']
        return
      end
      
      if opts['directories'] && opts['directories'].size>0
        ret[target_name][dep_name] = opts['directories']
      end
      
      if opts['minifier']
        if opts['minifier'].is_a? String
          ret[target_name]['bpm:minifier'] = {}
          ret[target_name]['bpm:minifier'][opts['minifier']] = '>= 0'
        else
          ret[target_name]['bpm:minifier'] = opts['minifier']
        end
      end

      Array(opts['include']).each do |package_name|
        dep = local_deps.find { |cur_dep| cur_dep.name == package_name }
        raise PackageNotFoundError.new(package_name, '>= 0') if dep.nil?
        tmp_settings = {}
        merge_build_settings(tmp_settings, dep, mode, true, true)
        if target_name =~ /\.css$/ && tmp_settings['bpm_styles.css']
          ret[target_name].merge! tmp_settings['bpm_styles.css']
        elsif target_name =~ /\.js$/ && tmp_settings['bpm_libs.js']
          ret[target_name].merge! tmp_settings['bpm_libs.js']
        end
      end
      
      bpm_settings = ret[target_name]['bpm:settings'] ||= {}
      ret[target_name]['bpm:settings'] = soft_merge(bpm_settings, opts)
      
    end

    def project_settings_excludes(dep_name, target_name)
      exclusions = bpm_build[target_name] && bpm_build[target_name]['exclude']
      exclusions && exclusions.include?(dep_name)
    end
     
    DEFAULT_BUILD_OPTS = {
      'bpm_libs.js' => {
        'directories' =>  ['lib'],
        'modes'       =>  ['*']
      },
      
      'bpm_styles.css' => {
        'directories' =>  ['css'],
        'modes'       =>  ['*']
      }
    }
    
    def soft_merge(base, ext)
      ret = base.dup
      ext.each do |key, value|
        if ret[key].is_a?(Hash) && value.is_a?(Hash)
          ret[key] = soft_merge(ret[key], value)
        else
          ret[key] = value
        end
      end
      ret
    end
    
    def default_build_opts(dep_name)
      @default_build_opts ||= {}
      ret = @default_build_opts[dep_name]
      if ret.nil?
        ret = DEFAULT_BUILD_OPTS.dup
        ret[dep_name] = { 
          "assets" => %w(resources assets), 
          "modes"  => ["*"] 
        }
        
        ret["#{dep_name}/bpm_tests.js"] = {
          'directories' => ['tests'],
          'modes'       => ['debug']
        }
        
        @default_build_opts[dep_name] = ret
      end
      ret
    end

    def merge_build_settings(ret, dep, mode, include_defaults=true, ignore_excludes=false)

      bpm_opts = dep.bpm_build
      if include_defaults
        bpm_opts = soft_merge default_build_opts(dep.name), bpm_opts
      end
      
      bpm_opts.each do |target_name, opts|
        next if !has_mode(opts, mode)
        next if !ignore_excludes && project_settings_excludes(dep.name, target_name)
        merge_build_opts ret, dep.name, target_name, opts, mode
      end
    end

  end

end
