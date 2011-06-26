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
      File.exists?(File.join(path, 'static', 'bpm_packages.js'))
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

      hard_deps = dependencies.dup
      new_deps.each { |pkg_name, pkg_vers| hard_deps[pkg_name] = pkg_vers }

      exp_deps = expand_local_packages hard_deps, true
      
      puts "Fetch missing packages..." if verbose
      core_fetch_dependencies exp_deps, :runtime, verbose

      verified_deps = install_and_verify_packages hard_deps, verbose
      remove_unused_packages verified_deps, verbose

      # the dependencies saved in the project file be the actual 
      # versions we installed. Replace the new deps verions passed in with
      # the actual versions used.
      new_deps.each do |package_name, _|
        hard_deps[package_name] = verified_deps[package_name]
      end
      
      @dependencies = hard_deps
      save!
    end

    def remove_dependencies(package_names, verbose=false)

      hard_deps = dependencies.dup
      package_names.each do |pkg_name|
        raise "'#{pkg_name}' is not a dependency" if hard_deps[pkg_name].nil?
        hard_deps.delete pkg_name
      end

      # note: never make this first call verbose because it will lead to 
      # confusing output
      verified_deps = install_and_verify_packages hard_deps, false
      remove_unused_packages verified_deps, verbose
      
      @dependencies = hard_deps
      save!
    end

    def update(verbose=false)
      core_fetch_dependencies dependencies, :runtime, verbose
      install_and_verify_packages dependencies, verbose
    end
    
    def save!
      @had_changes = false
      File.open @json_path, 'w+' do |fd|
        fd.write as_json.to_json
      end
    end
    
    def fetch_dependencies(verbose=false)
      core_fetch_dependencies(dependencies, :runtime, verbose)
    end

    def compile_dependencies(mode=:production, verbose=false)
      local_deps.map{|d| d.compile(mode, root_path, verbose) }.flatten
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
        lock_path    = File.join package_root, 'bpm.lock'
        
        if File.exists?(package_root) && !File.exists?(lock_path)
          pkg = BPM::Package.new package_root
          pkg.load_json
          puts "Using local package '#{pkg.name}' (#{pkg.version})" if verbose
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
      installed.each do |i|
        cur_installed.reject! { |ci| ci.name == i.name && ci.version == i.version }
      end

      installed = installed.find { |i| i.name == package_name }
      if cur_installed.size>0
        puts "Fetched #{installed.name} (#{installed.version}) from remote" 
      end
    end

    def install_and_verify_packages(deps, verbose)
      puts "Installing and verifying packages..." if verbose

      todo = []
      seen = []
      verified  = {}
      
      deps.each { |package_name, vers| todo << [package_name, vers] }
      local = BPM::Local.new

      while todo.size>0
        package_name, vers = todo.shift
        next if seen.include? package_name
        seen << package_name
        
        dst_path = File.join @root_path, 'packages', package_name

        if has_local_package? package_name 
          puts "Skipping local package #{package_name}" if verbose
          pkg = BPM::Package.new dst_path
          
        else

          # get the locally installs dep
          if vers == '>= 0-pre'
            prerel = true
            vers   = '>= 0'
          else
            prerel = vers =~ /[a-zA-Z]/
          end
          
          preferred_vers = local.preferred_version package_name, vers, prerel
          
          if File.exist?(dst_path)
            pkg = BPM::Package.new dst_path
            pkg.load_json
            pkg = nil unless pkg.version == preferred_vers
          else
            pkg = nil
          end

          # copy pkg if needed
          if pkg.nil?

            src_path = local.source_root package_name, preferred_vers, prerel
            
            FileUtils.rm_r dst_path if File.exists? dst_path
            FileUtils.mkdir_p File.dirname(dst_path) #, :mode => 0755
            FileUtils.cp_r src_path, dst_path
            
            # Add lock file - this allows us to distinguish between packages
            # managed by bpm and those that are installed locally 
            File.open(File.join(dst_path, 'bpm.lock'), 'w+') do |fd|
              fd << "IMPORTANT: This file is automatically generated for packages managed by bpm.  Do not remove or modify this file yourself."
            end
              
            pkg = BPM::Package.new dst_path
            pkg.load_json
            puts "Added #{pkg.name} (#{pkg.version})" 
            
          else
            puts "Skipping installed package #{package_name} (#{preferred_vers})" if verbose
          end
          
        end

        # add dependencies to list
        if pkg.valid?
          pkg.dependencies.each do |dep_name, dep_vers|
            todo << [dep_name, dep_vers]
          end
        end

        verified[pkg.name] = pkg.version
      end
      
      verified
        
    end

    def remove_unused_packages(used_packages, verbose)
      packages_path = File.join @root_path, 'packages'
      Dir.glob(File.join(packages_path, '*')).each do |package_name|
        package_name = File.basename package_name
        
        next if used_packages.include? package_name 
        next if has_local_package? package_name
        FileUtils.rm_r File.join(packages_path, package_name)
        puts "Removed unused package '#{package_name}'"
      end
    end
    
    def has_local_package?(package_name)
      package_root = File.join @root_path, 'packages', package_name
      lock_path    = File.join package_root, 'bpm.lock'
      File.exists?(package_root) && !File.exists?(lock_path)
    end

    
  end

end
