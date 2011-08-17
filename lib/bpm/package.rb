require 'json'

module BPM
  class Package
    EXT = "bpkg"

    # All JSON fields
    FIELDS = {
      "keywords"    => :array,
      "licenses"    => :array,
      "engines"     => :array,
      "main"        => :string,
      "bin"         => :hash,
      "directories" => :hash,
      "pipeline"    => :hash,
      "name"        => :string,
      "version"     => :string,
      "description" => :string,
      "author"      => :string,
      "homepage"    => :string,
      "summary"     => :string,
      "dependencies"             => :hash,
      "dependencies:development" => :hash,
      "bpm:build"         => :hash,
      "bpm:use:transport" => :string,
      "bpm:provides"      => :hash
    }

    PLUGIN_TYPES = %w[minifier]

    # Fields that can be loaded straight into the gemspec
    SPEC_FIELDS = %w[name email]

    # Fields that should be bundled up into JSON in the gemspec
    METADATA_FIELDS = %w[keywords licenses engines main bin directories pipeline bpm:build]

    REQUIRED_FIELDS = %w[name version summary]

    attr_accessor *FIELDS.keys.map{|f| f.gsub(':', '_') }

    attr_accessor :json_path, :email
    attr_reader :root_path, :errors

    def self.from_spec(spec)
      pkg = new(spec.full_gem_path)
      pkg.fill_from_gemspec(spec)
      pkg
    end

    def initialize(root_path=nil, config={})
      @root_path   = root_path || Dir.pwd
      @json_path   = File.join @root_path, 'bpm_package.json'
      unless File.exists? @json_path
        @json_path   = File.join @root_path, 'package.json'
      end
      
      @email       = config[:email]
      @standalone  = config[:standalone]
      @errors      = []
      # Set defaults
      FIELDS.keys.each{|f| send("#{c2u(f)}=", fd(f))}
    end

    def to_spec
      return unless valid?
      LibGems::Specification.new do |spec|
        SPEC_FIELDS.each{|f| spec.send("#{f}=", send(f)) }
        spec.version      = version
        spec.authors      = [author] if author
        spec.files        = directory_files + ["package.json"]
        spec.test_files   = glob_files(tests_path)
        spec.bindir       = bin_path
        spec.licenses     = licenses.map{|l| l["type"]}
        spec.executables  = bin_files.map{|p| File.basename(p) } if bin_path

        spec.homepage     = self.homepage
        spec.summary      = self.summary
        spec.description  = self.description if self.description

        metadata = Hash[METADATA_FIELDS.map{|f| [f, send(c2u(f)) ] }]
        spec.requirements = [metadata.to_json]

        # TODO: Is this right?
        spec.rubyforge_project = "bpm"

        def spec.file_name
          "#{full_name}.#{EXT}"
        end

        dependencies.each{|d,v| spec.add_dependency(d,v) }
        dependencies_development.each{|d,v| spec.add_development_dependency(d,v) }
      end
    end

    def as_json

      seen_keys = @read_keys || []
      json   = {}
      
      # keep order of keys read in
      seen_keys.each do |key|
        if FIELDS.include?(key)
          val = send(c2u(key == 'build' ? 'pipeline' : key))
        else
          val = @attributes[key]
        end
        
        json[key] = val if val && !val.empty?
      end
      
      FIELDS.keys.each do |key|
        next if seen_keys.include?(key)
        val = send(c2u(key))
        key = 'build' if key == 'pipeline'
        json[key] = val if val && !val.empty?
      end

      json
    end

    def to_json
      as_json.to_json
    end

    def shell
      @shell ||= Thor::Base.shell.new
    end
    
    def say(*args)
      shell.say *args
    end
    
    def full_name
      "#{name}-#{version}"
    end

    def file_name
      "#{full_name}.#{EXT}"
    end

    def directory_files
      dir_names = [bin_path, lib_path, tests_path]
      dir_names += directories.reject { |k,_| dir_names.include?(k) }.values
      dir_names.reject! { |t| t == tests_path }
      
      build_names = bpm_build.values.map do |hash|
        hash['directories'] || hash['assets']
      end

      build_names += PLUGIN_TYPES.map do |type|
        val = bpm_provides[type]
        val = val && val =~ /^#{name}\// ? val[name.size+1..-1]+'.js' : nil
        val
      end

      bpm_provides.each do |_,values|
        val = values['main']
        val = val && val =~ /^#{name}\// ? val[name.size+1..-1]+'.js' : nil
        build_names << val if val
      end

      (dir_names+build_names).flatten.compact.uniq.map do |dir| 
        glob_files(dir)
      end.flatten
    end

    def bin_files
      bin && bin.values
    end

    def bin_path
      directories["bin"] || "bin"
    end

    def lib_path
      directories["lib"] || "lib"
    end

    def tests_path
      directories["tests"] || "tests"
    end

    def find_transport_plugins(project)
      dependencies.keys.map do |pkg_name|
        dep = project.local_deps.find do |pkg|
          pkg.load_json
          pkg.name == pkg_name
        end
        raise "Could not find dependency: #{pkg_name}" unless dep
        dep.provided_transport
      end.compact
    end

    def pipeline_libs
      (pipeline && pipeline['libs']) || ['lib']
    end

    def pipeline_css
      (pipeline && pipeline['css']) || ['css']
    end

    def pipeline_assets
      (pipeline && pipeline['assets']) || ['assets', 'resources']
    end

    def pipeline_tests
      (pipeline && pipeline['tests']) || ['tests']
    end
    
    # Returns a hash of dependencies inferred from the build settings.
    def dependencies_build
      ret = {}

      bpm_build.each do |target_name, opts|
        next unless opts.is_a?(Hash)
        
        minifier = opts['minifier']
        case minifier
        when String
          ret[minifier] = '>= 0'
        when Hash
          ret.merge! minifier
        end
      end
      
      bpm_provides.each do |_,opts|
        next unless opts.is_a?(Hash) && opts['dependencies']
        ret.merge! opts['dependencies']
      end

      ret
    end
    
    def template_path(name)
      path = File.join(root_path, 'templates', name.to_s)
      File.exist?(path) ? path : nil
    end

    def generator_for(type)
      unless generator = BPM.generator_for(name, type, false)
        path = File.join(root_path, 'templates', "#{type}_generator.rb")
        load path if File.exist?(path)
        generator = BPM.generator_for(name, type)
      end
      generator
    end

    def standalone?
      !!@standalone
    end

    def validate
      validate_fields && validate_version && validate_paths
    end

    def valid?
      load_json && validate
    end

    def has_json?
      !!json_path && File.exist?(json_path)
    end

    def validate_name_and_path
      # Currently we're only validating this for vendored packages
      return if standalone?

      dirname = File.basename(root_path)
      unless name.nil? || name.empty? || dirname == name || (version && dirname == "#{name}-#{version}")
        raise BPM::InvalidPackagePathError.new(self)
      end
    end

    def load_json
      begin
        json = JSON.parse(File.read(@json_path))
      rescue JSON::ParserError, Errno::EACCES, Errno::ENOENT => ex
        raise BPM::InvalidPackageError.new self, ex.message
      end

      @read_keys = json.keys.dup # to retain order on save
      @attributes = json # save for saving
      
      FIELDS.keys.each do |field|
        if field == 'pipeline'
          self.pipeline = json['build'] || fd(field)
        else
          send("#{c2u(field)}=", json[field] || fd(field))
        end
      end

      validate_name_and_path
      
      true
    end

    def fill_from_gemspec(spec)
      unless spec.is_a?(LibGems::Specification)
        spec = LibGems::Format.from_file_by_path(spec.to_s).spec
      end

      SPEC_FIELDS.each{|f| send("#{f}=", spec.send(f) || fd(field)) }

      self.author = spec.authors.first
      self.version = spec.version.to_s

      self.description = spec.description
      self.summary     = spec.summary
      self.homepage    = spec.homepage

      metadata = spec.requirements.first
      if metadata
        metadata = JSON.parse(metadata)
        METADATA_FIELDS.each{|f| send("#{c2u(f)}=", metadata[f] || fd(f))}
      end

      self.dependencies = Hash[spec.dependencies.map{|d| [d.name, d.requirement.to_s ]}]
      self.dependencies_development = Hash[spec.development_dependencies.map{|d| [d.name, d.requirement.to_s ]}]
    end

    # Collects an expanded list of all dependencies this package depends on 
    # directly or indirectly.  This assume the project has already resolved
    # any needed dependencies and therefore will raise an exception if a 
    # dependency cannot be found locally in the project.
    def expanded_deps(project)
      ret  = []
      seen = []
      todo = [self]
      while todo.size > 0
        pkg = todo.shift
        pkg.dependencies.each do |dep_name, dep_vers|
          next if seen.include? dep_name
          seen << dep_name
          found = project.local_deps.find { |x| x.name == dep_name }
          if found
            todo << found
            ret  << found
          else
            raise "Required local dependency not found #{dep_name}"
          end
        end
      end
      ret
    end

    def merged_dependencies(*kinds)
      kinds.inject({}) do |ret, kind|
        deps = case kind
        when :runtime
          dependencies
        when :development
          dependencies_development
        when :build
          dependencies_build
        end
        ret.merge! deps
      end
    end
    
    def used_dependencies(project)
      if project.has_local_package?(self.name) 
        merged_dependencies(:runtime, :development)
      else
        merged_dependencies(:runtime)
      end
    end
      
    def provided_formats
      ret = {}
      bpm_provides.each do | key, opts |
        ret[key[7..-1]] = opts if key =~ /^format:/
      end
      ret
    end

    def used_formats(project)
      pkgs=project.map_to_packages used_dependencies(project)
      pkgs.inject({}) { |ret, pkg| ret.merge!(pkg.provided_formats) }
    end

    def provided_preprocessors
      bpm_provides['preprocessors'] || []
    end

    def used_preprocessors(project)
      pkgs=project.map_to_packages used_dependencies(project)
      pkgs.map { |pkg| pkg.provided_postprocessors }.flatten
    end
    
    def provided_postprocessors
      bpm_provides['postprocessors'] || []
    end

    def used_postprocessors(project)
      pkgs=project.map_to_packages used_dependencies(project)
      pkgs.map { |pkg| pkg.provided_postprocessors }.flatten
    end
    
    def provided_transport
      bpm_provides['transport']
    end

    def used_transports(project)
      pkgs=project.map_to_packages used_dependencies(project)
      pkgs.map { |pkg| pkg.provided_transport }.compact.flatten
    end

    def provided_minifier
      bpm_provides['minifier']
    end

    # TODO: Make better errors
    # TODO: This might not work well with conflicting versions
    def local_deps(search_path=nil)
      search_path ||= File.join(root_path, "packages")

      dependencies.inject([]) do |list, (name, version)|
        package = Package.new(File.join(search_path, name))
        requirement = LibGems::Requirement.new(version)
        if package.has_json?
          package.load_json
        else
          raise "Can't find package #{name} required in #{self.name}"
        end
        unless requirement.satisfied_by?(LibGems::Version.new(package.version))
          raise "#{name} (#{package.version}) doesn't match #{version} required in #{self.name}"
        end
        (package.local_deps(search_path) << package).each do |dep|
          list << dep unless list.any?{|d| d.name == dep.name }
        end
        list
      end
    end

    private

      # colon to underscore
      def c2u(key)
        key.gsub(':', '_')
      end

      # field default
      def fd(key)
        case FIELDS[key]
        when :array then []
        when :hash  then {}
        end
      end

      def validate_paths
        success = true

        paths = [*lib_path]
        if paths.empty?
          add_error "A lib directory is required"
          success = false
        else
          non_dirs = paths.reject{|p| File.directory?(File.join(root_path, p))}
          unless non_dirs.empty?
            add_error "#{non_dirs.map{|p| "'#{p}'" }.join(", ")}, specified for lib directory, is not a directory"
            success = false
          end
        end

        # look for actual 'tests' in directories hash since simply having no
        # tests dir is allowed as well.
        unless directories['tests'].nil? || File.directory?(File.join(@root_path, tests_path))
          add_error "'#{tests_path}', specified for tests directory, is not a directory"
          success = false
        end

        success
      end

      def validate_version
        LibGems::Version.new(version)
        true
      rescue ArgumentError => ex
        add_error ex.to_s
        false
      end

      def validate_fields
        REQUIRED_FIELDS.all? do |field|
          value = send(field)
          if value.nil? || value.empty?
            add_error "Package requires a '#{field}' field"
            false
          else
            true
          end
        end
      end

      def add_error(message)
        self.errors << message unless self.errors.include?(message)
      end

      def glob_files(path)
        return path if File.exists?(path) && !File.directory?(path)
        Dir[File.join(path, "**", "*")].reject{|f| File.directory?(f) }
      end

  end
end
