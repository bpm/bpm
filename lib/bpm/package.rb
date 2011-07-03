require 'json'

module BPM
  class Package
    EXT      = "bpkg"
    METADATA = %w[keywords licenses engines main bin directories]
    FIELDS   = %w[name version description author homepage summary]
    attr_accessor :metadata, :lib_path, :tests_path, :errors, :json_path, :attributes, :directories, :dependencies, :root_path
    attr_accessor *FIELDS

    def self.from_spec(spec)
      pkg = new(spec.full_gem_path)
      pkg.bpkg = spec
      pkg
    end

    def initialize(root_path=nil, email = "")
      @root_path = root_path || Dir.pwd
      @json_path = File.join @root_path, 'package.json'
      @email     = email
      @attributes = {}
      @dependencies = {}
      @directories = {}
      @metadata = {}
    end

    def bpkg=(spec)
      unless spec.is_a?(LibGems::Specification)
        spec = LibGems::Format.from_file_by_path(spec.to_s).spec
      end
      fill_from_gemspec(spec)
    end

    def to_spec
      return unless valid?
      LibGems::Specification.new do |spec|
        spec.name              = name
        spec.version           = version
        spec.authors           = [author]
        spec.email             = @email
        spec.homepage          = homepage
        spec.summary           = summary
        spec.description       = description
        spec.requirements      = [metadata.to_json]
        spec.files             = directory_files + template_files + transport_files + ["package.json"]
        spec.test_files        = glob_files(tests_path)
        spec.bindir            = bin_path
        spec.executables       = bin_files.map{|p| File.basename(p) } if bin_path
        # TODO: IS this right?
        spec.rubyforge_project = "bpm"
        def spec.file_name
          "#{full_name}.#{EXT}"
        end
        dependencies.each{|d,v| spec.add_dependency(d, v) } if dependencies
      end
    end

    def as_json(options = {})
      json = self.metadata.clone
      FIELDS.each{|key| json[key] = send(key)}
      json["dependencies"] = self.dependencies
      json
    end

    def to_json
      as_json.to_json
    end

    def to_full_name
      "#{name}-#{version}"
    end

    def to_ext
      "#{self.to_full_name}.#{EXT}"
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

    def errors
      @errors ||= []
    end

    def validate
      validate_fields && validate_version && validate_paths
    end

    def valid?
      load_json && validate
    end

    def has_json?
      File.exist?(json_path)
    end

    def load_json
      read && parse
    end

    def expanded_deps(project)
      ret  = []
      seen = []
      todo = [self]
      while todo.size > 0
        pkg = todo.shift
        pkg.dependencies.each do |dep_name|
          next if seen.include? dep_name
          seen << dep_name
          found = project.local_deps.find { |x| x.name == dep_name }
          todo << found
          ret  << found
        end
      end
      ret
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

    def directory_files
      directories.reject{|k,_| k == 'tests' }.values.map{|dir| glob_files(dir) }.flatten
    end

    def bin_files
      if @attributes["bin"]
        @attributes["bin"].values
      else
        []
      end
    end

    def template_files
      glob_files("templates")
    end

    def transport_files
      glob_files("transports")
    end

    def bin_path
      @directories["bin"] || "bin"
    end

    def lib_path
      @directories["lib"] || "lib"
    end

    def tests_path
      @directories["tests"] || "tests"
    end

    def transport_plugins(project)
      plugin_modules('plugin:transport', project, false)
    end
    
    def minifier_plugins(project)
      [@attributes['plugin:minifier']].compact
    end

    def plugin_modules(key_name, project, own=true)
      return [@attributes[key_name]] if own && @attributes[key_name]
      dependencies.keys.map do |pkg_name| 
        dep = project.local_deps.find do |pkg| 
          pkg.load_json
          pkg.name == pkg_name
        end
        dep.attributes[key_name]
      end.compact
    end
      
    # named directories that are expected to contain code.  These will be 
    # searched for supported modules
    def pipeline_libs
      (@attributes['pipeline'] && @attributes['pipeline']['libs']) || ['lib']
    end

    def pipeline_css
      (@attributes['pipeline'] && @attributes['pipeline']['css']) || ['css']
    end

    def pipeline_assets
      (@attributes['pipeline'] && @attributes['pipeline']['assets']) || ['assets', 'resources']
    end

  private
  
    def parse
      FIELDS.each do |field|
        send("#{field}=", @attributes[field])
      end

      self.dependencies = @attributes["dependencies"] || {}
      self.directories = @attributes["directories"] || {}
      self.metadata    = Hash[*@attributes.select { |k, v| METADATA.include?(k) }.flatten(1)]
    end

    def read
      @attributes = JSON.parse(File.read(@json_path))
    rescue *[JSON::ParserError, Errno::EACCES, Errno::ENOENT] => ex
      add_error "There was a problem parsing #{File.basename(@json_path)}: #{ex.message}"
    end

    def validate_paths
      success = true

      if paths = [*lib_path]
        non_dirs = paths.reject{|p| File.directory?(File.join(@root_path, p))}
        if paths.empty?
          add_error "A lib directory is required"
          success = false
        elsif !non_dirs.empty?
          add_error "#{non_dirs.map{|p| "'#{p}'" }.join(", ")}, specified for lib directory, is not a directory"
          success = false
        end
      end

      # look for actual 'tests' in directories hash since simply having no
      # tests dir is allowed as well.
      unless @directories['tests'].nil? || File.directory?(File.join(@root_path, tests_path))
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
    end

    def validate_fields
      %w[name description summary homepage author version directories].all? do |field|
        value = send(field)
        if value.nil? || value.size.zero?
          add_error "Package requires a '#{field}' field"
        else
          true
        end
      end
    end

    def add_error(message)
      self.errors << message
      false
    end

    def glob_files(path)
      Dir[File.join(path, "**", "*")].reject{|f| File.directory?(f) }
    end

    def fill_from_gemspec(spec)
      FIELDS.each{|field| send("#{field}=", spec.send(field).to_s) }

      self.dependencies = {}
      spec.dependencies.each{|d| self.dependencies[d.name] = d.requirement.to_s }

      if spec.requirements && spec.requirements.size>0
        self.metadata = JSON.parse(spec.requirements.first)
      end
    end

  end
end

