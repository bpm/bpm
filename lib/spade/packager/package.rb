require 'json'

module Spade::Packager
  class Package
    EXT      = "spd"
    METADATA = %w[keywords licenses engines main bin directories]
    FIELDS   = %w[name version description author homepage summary]
    attr_accessor :metadata, :lib_path, :test_path, :errors, :json_path, :attributes, :directories, :dependencies
    attr_accessor *FIELDS

    def initialize(email = "")
      @email = email
    end

    def spade=(path)
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
        spec.test_files        = glob_files(test_path) if test_path
        spec.bindir            = bin_path
        spec.executables       = bin_files.map{|p| File.basename(p) } if bin_path
        spec.rubyforge_project = "spade"
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
      read && parse && validate
    end

    private

    def directory_files
      directories.values.map{|dir| glob_files(dir) }.flatten
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
      @directories["lib"]
    end

    def test_path
      @directories["test"]
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
      add_error "There was a problem parsing package.json: #{ex.message}"
    end

    def validate_paths
      %w[lib test].all? do |directory|
        path = send("#{directory}_path")
        if path.nil? || File.directory?(File.join(Dir.pwd, path))
          true
        else
          add_error "'#{path}' specified for #{directory} directory, is not a directory"
        end
      end
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

