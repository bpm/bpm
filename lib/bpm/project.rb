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
      read && parse && validate
    end

    def dirty?
      @has_changes || false
    end

    def dirty!
      @has_changes = true
    end

    def add_dependency(package_name, package_version)
      if dependencies[package_name] != package_version
        dependencies[package_name] = package_version
        dirty!
      else
        false
      end
    end

    def remove_dependency(package_name)
      if dependencies[package_name]
        dependencies.delete(package_name)
        dirty!
      else
        false
      end
    end

    def fetch_dependencies(verbose=false)
      core_fetch_dependencies(dependencies, :runtime, verbose)
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

    def core_fetch_dependencies(deps, kind, verbose)
      success = true

      deps.each do |package_name, package_version|

        dep = LibGems::Dependency.new(package_name, ">= #{package_version}", kind)
        installed = LibGems.source_index.search(dep)

        if installed.empty?
          puts "Fetching #{package_name} (#{package_version}) from remote" if verbose

          installed = BPM::Remote.new.install(package_name, package_version, false)
          installed = installed.find { |i| i.name == package_name }
          if (installed)
            puts "Fetched #{installed.name} (#{installed.version}) from remote" if verbose
          else
            add_error("Unable to find #{package_name} #{package_version} to fetch")
            success = false
          end
        end
      end

      success
    end

  end

end
