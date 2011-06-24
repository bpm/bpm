require 'json'

module BPM
  class Package
    EXT      = "spd"
    METADATA = %w[keywords licenses engines main bin directories bpm]
    FIELDS   = %w[name version description author homepage summary]
    attr_accessor :metadata, :lib_path, :tests_path, :errors, :json_path, :attributes, :directories, :dependencies, :root_path
    attr_accessor *FIELDS

    def initialize(root_path=nil, email = "")
      @root_path = root_path || Dir.pwd
      @json_path = File.join @root_path, 'package.json'
      @email     = email
      @attributes = {}
      @directories = {}
      @metadata = {}
    end

    def bpm
      @bpm || BPM::VERSION
    end

    def bpkg=(path)
      format = LibGems::Format.from_file_by_path(path)
      fill_from_gemspec(format.spec)
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
        spec.files             = directory_files + ["package.json"]
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

    def compile(mode=:production, project_path=root_path, verbose=false)
      puts "Compiling #{name}" if verbose

      require 'spade'
      out = []
      Spade::MainContext.new(:rootdir => project_path) do |ctx|
        packages_path = File.join(project_path, "packages")
        (local_deps(packages_path) << self).each do |pkg|
          ctx.eval("spade.register(\"#{pkg.name}\", #{File.read(pkg.json_path)});");
        end

        paths = [*lib_path].map{|p| File.join(root_path, p) }
        ids = paths.map do |p|
          p += '/' if p[-1] != '/'
          glob_files(p).map do |f|
            f.sub(p, '').sub(/\.[^\.]+$/,'')
          end
        end.flatten
        ids.each do |id|
          puts "    #{name}/#{id}" if verbose
          out << ctx.eval("spade.compile(\"#{name}/#{id}\", \"#{name}\");")
        end
      end

      out.compact
    end

    private

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

    def bin_path
      @directories["bin"] || "bin"
    end

    def lib_path
      @directories["lib"] || "lib"
    end

    def tests_path
      @directories["tests"] || "tests"
    end

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

      unless tests_path.nil? || File.directory?(File.join(@root_path, tests_path))
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

      self.metadata = JSON.parse(spec.requirements.first)
    end

  end
end

