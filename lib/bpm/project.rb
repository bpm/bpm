require 'json'
require 'set'
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
      @json_path = project_file || File.join(root_path, "#{File.basename(root_path)}.json")

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

    def vendor_root
      File.join @root_path, 'vendor'
    end

    def vendored_projects
      @vendored_projects ||= begin
        Dir.glob(File.join(vendor_root, '*')).
          select{|p| Project.is_project_root?(p) }.
          map{|p| Project.new(p) }
      end
    end

    def vendored_packages
      @vendored_packages ||= begin
        # Packages path is deprecated
        packages_path = File.join(@root_path, 'packages')
        search_paths = [vendor_root, packages_path]
        paths = search_paths.map{|p| Dir.glob(File.join(p, '*')) }.flatten
        pkgs = paths.select{|p| Package.is_package_root?(p) }.map{|p| Package.new(p) }
        if pkgs.any?{|p| p.root_path =~ /^#{Regexp.escape(packages_path)}\// }
          warn "[DEPRECATION] Use the vendor directory instead of the packages directory for #{root_path}" unless BPM::CLI::Base.suppress_deprecations
        end
        pkgs += vendored_projects.map{|p| p.vendored_packages }.flatten
        pkgs.select do |p|
          begin
            p.load_json
          rescue BPM::InvalidPackageError
            false
          end
        end
      end
    end

    def find_vendored_project(name)
      vendored_projects.find{|p| p.name == name }
    end

    def find_vendored_package(name)
      vendored_packages.find{|p| p.name == name }
    end

    def package_manifest_path
      File.join(@root_path, BPM_DIR, 'package_manifest.json')
    end

    def assets_path
      'assets'
    end

    def assets_root(*paths)
      File.join @root_path, assets_path, *paths
    end

    def preview_root(*paths)
      File.join @root_path, '.bpm', 'preview', *paths
    end

    def build_app?
      # Make sure we have some lib files
      !!(bpm_build &&
          bpm_build["bpm_libs.js"] &&
          ((bpm_build["bpm_libs.js"]["files"] && bpm_build["bpm_libs.js"]["files"].size>0) ||
            (bpm_build["bpm_libs.js"]["directories"] && bpm_build["bpm_libs.js"]["directories"].size>0)))
    end

    def build_app=(value)
      bpm_libs = "bpm_libs.js"
      bpm_styles = "bpm_styles.css"

      if value
        bpm_build[bpm_libs] ||= {}
        hash = bpm_build[bpm_libs]
        hash['files'] ||= hash['directories'] || []
        hash['files'] << 'lib' if hash['files'].size==0
        hash['minifier']    ||= 'uglify-js'

        bpm_build[bpm_styles] ||= {}
        hash = bpm_build[bpm_styles]
        hash['files'] ||= hash['directories'] || []
        hash['files'] << 'css' if hash['files'].size==0

        directories ||= {}
        directories['lib'] ||= ['lib']
      else
        bpm_build[bpm_libs]['files'] = []
        bpm_build[bpm_styles]['files'] = []
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

      say "Fetching packages from remote..." if verbose
      core_fetch_dependencies(exp_deps, verbose)

      if development
        self.dependencies_development = hard_deps
      else
        self.dependencies = hard_deps
      end

      rebuild_dependency_list(all_hard_deps, verbose)

      local_deps.each do |dep|
        next if old_deps.find { |pkg| (pkg.name == dep.name) && (pkg.version == dep.version) }
        say "Added #{development ? "development " : ""}package '#{dep.name}' (#{dep.version})"
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
        say "Removed package '#{dep.name}' (#{dep.version})"
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
      say "Fetching packages from remote..." if verbose
      exp_deps = find_non_local_dependencies(all_dependencies, true)
      core_fetch_dependencies(exp_deps, verbose)
    end


    # Builds assets directory for dependent packages

    def build(mode=:debug, verbose=false)

      verify_and_repair mode, verbose

      say "Building static assets..." if verbose

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
          say "~ Copying #{asset.logical_path}" if verbose
          FileUtils.rm dst_path if File.exists? dst_path
          FileUtils.cp asset.pathname, dst_path
        else
          $stdout << "~ Building #{asset.logical_path}..." if verbose
          File.open(dst_path, 'w+') { |fd| fd << asset.to_s }
          if verbose
            gzip_size = LibGems.gzip(asset.to_s).bytesize
            gzip_size = gzip_size < 1024 ? "#{gzip_size} bytes" : "#{gzip_size / 1024} Kb"
            $stdout << " (gzipped size: #{gzip_size})\n"
          end
        end
      end

      say "\n" if verbose
    end


    # Removes any built assets from the project.  Usually called before a
    # package is removed from the project to cleanup any assets

    def unbuild(verbose=false)
      say "Removing stale assets..." if verbose

      pipeline = BPM::Pipeline.new self
      asset_root = File.join root_path, 'assets'
      pipeline.buildable_assets.each do |asset|
        next if asset.logical_path =~ /^bpm_/
        asset_path = File.join asset_root, asset.logical_path
        next unless File.exists? asset_path
        say "~ Removing #{asset.logical_path}" if verbose
        FileUtils.rm asset_path

        # cleanup empty directories
        while !File.exists?(asset_path)
          asset_path = File.dirname asset_path
          FileUtils.rmdir(asset_path) if File.directory?(asset_path)
          if verbose && !File.exists?(asset_path)
            say "~ Removed empty directory #{File.basename asset_path}"
          end
        end
      end

      say "\n" if verbose
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

    def map_to_packages(deps)
      Array(deps).map do |dep_name, vers|
        local_deps.find { |x| x.name==dep_name }
      end
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

      json = {}
      found.each do |f|
        json[f.name] = { :version => f.version.to_s, :path => f.root_path }
      end

      FileUtils.mkdir_p(File.dirname(package_manifest_path))
      File.open(package_manifest_path, 'w') do |f|
        f.puts JSON.pretty_generate(json)
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
      build_settings[asset_name] &&
        build_settings[asset_name]['bpm:provides'] &&
        build_settings[asset_name]['bpm:provides']['minifier']
    end

    def load_json
      return super if has_json?
      (FIELDS.keys + %w(description summary homepage)).each do |f|
        send("#{c2u(f)}=", DEFAULT_CONFIG[f])
      end

      self.name = File.basename(@json_path, '.json')
      self.version = "0.0.1"
      true
    end

    # Tell if package is vendored

    def has_local_package?(package_name)
      !!find_vendored_package(package_name)
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
        version = check_version(version)
        next if seen.include?(name)
        seen << name

        pkg = find_vendored_package(name)
        if pkg
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
      vers = check_version(vers)
      prerelease = false
      if vers == '>= 0.pre'
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
        say "~ Fetched #{i.name} (#{i.version}) from remote" if verbose
      end

    end


    # Get list of local dep names from the .bpm directory
    #
    # Pass +false+ to prevent the list from being rebuilt

    def build_local_dependency_list(force=true)
      unless File.exist?(package_manifest_path)
        return nil unless force
        rebuild_dependency_list
      end

      manifest = JSON.parse(File.read(package_manifest_path))
      manifest.map do |name, data|
        pkg = BPM::Package.new(data['path'])
        pkg.load_json
        pkg
      end
    end

    # Get list of dependencies, searching only the project and fetched
    # packages.  Raises if not found or
    # conflicting.
    def find_dependencies(deps=nil, verbose=false)

      deps ||= all_dependencies

      search_list = Array(deps)
      found = []
      ret = []

      # if we discover a new local package via indirect dependencies then
      # it's dependencies will be fetchable one time.
      fetchable = Set.new

      until search_list.empty?
        name, version = search_list.shift

        if dup = found.find{|p| p.name == name}
          # already found, check for conflicts
          next if satisfied_by?(version, dup.version)
          raise PackageConflictError.new(name, dup.version, version)
        end

        pkg = locate_package(name, version, verbose)
        if pkg.nil? && fetchable.include?(name)
          fetchable.reject! { |x| x == name }
          core_fetch_dependency(name, version, :runtime, true)
          pkg = locate_package name, version, verbose
        end

        raise PackageNotFoundError.new(name, version) unless pkg

        found << pkg

        # Look up dependencies of dependencies
        new_deps = Array(pkg.dependencies) + Array(pkg.dependencies_build)
        if has_local_package? pkg.name
          new_deps += Array(pkg.dependencies_development)
          new_deps.each { |dep| fetchable.add dep.first }
        end

        search_list += new_deps

        ret << pkg
      end

      ret
    end


    # Find package locally or in global cache

    def locate_package(package_name, vers, verbose)
      pkg = find_vendored_package(package_name)
      # FIXME: Make sure that local packages match specified version as well

      unless pkg
        # It's true that we don't have a prerelase check here, but the
        # previous one we had didn't do anything, so it's better to have
        # none than one that doesn't work
        vers = check_version(vers)
        vers = ">= 0" if vers == ">= 0.pre"

        src_path = BPM::Local.new.source_root(package_name, vers)
        pkg = BPM::Package.new(src_path) if src_path # Do we need this check?
        pkg.load_json if pkg
      end

      return nil unless pkg

      pkg
    end

    # pass in a hash of dependencies and versions
    def report_package_locations(deps=nil)
      deps ||= local_deps
      deps.each do |dep|
        is_local = has_local_package?(dep.name) ? 'local' : 'fetched'
        say "~ Using #{is_local} package '#{dep.name}' (#{dep.version})"
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

      if opts['directories']
        warn "[DEPRECATION] Use 'files' array instead of 'directories' array in #{dep_name} config"  unless BPM::CLI::Base.suppress_deprecations
        opts['files'] ||= []
        opts['files'] += opts.delete('directories')
      end

      if opts['files'] && opts['files'].size>0
        ret[target_name][dep_name] = opts['files']
      end

      if opts['minifier']
        ret[target_name]['bpm:provides'] ||= {}
        if opts['minifier'].is_a? String
          ret[target_name]['bpm:provides']['minifier'] = {}
          ret[target_name]['bpm:provides']['minifier'][opts['minifier']] = '>= 0'
        else
          ret[target_name]['bpm:provides']['minifier'] = opts['minifier']
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
        'files' =>  ['lib'],
        'modes' =>  ['*']
      },

      'bpm_styles.css' => {
        'files' =>  ['css'],
        'modes' =>  ['*']
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
          'files' => ['tests'],
          'modes' => ['debug']
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

    def check_version(vers)
      if vers == '>= 0-pre'
        warn "[DEPRECATION] Use '>= 0.pre' in your JSON config instead of '>= 0-pre'." unless BPM::CLI::Base.suppress_deprecations
        vers = '>= 0.pre'
      end
      vers
    end

  end

end
