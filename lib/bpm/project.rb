require 'json'

module BPM
  
  class Project
    
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
    
    def self.nearest_project(thor, path)

      path = File.expand_path path
      
      last = nil
      while path != last
        return new(thor, path) if is_project_root?(path)
        last = path
        path = File.dirname path
      end
      nil
    end

    attr_reader :path
    
    def initialize(thor, path)
      @path = path
      @thor = thor
    end
    
    # Updates the bpm_package.js and css files based on project configs
    def compile(mode=:debug, verbose=false)
      puts "COMPILED mode=#{mode} verbose=#{verbose ? 'true' : 'false'}"
    end

    # Returns normalized JSON config hashes for the project.  If the project
    # does not contain a config then a default one is generated.
    def project_config
      path = self.class.project_file_path(@path)
      
      if path.nil?
        normalize_config(DEFAULT_CONFIG.dup, @path)
      else
        normalize_config(JSON.load(File.read(path)), path)
      end
    end
    
  private

    def normalize_config(config, path)
      config["name"] ||= File.basename(path, '.json')
      config["__filename"] = path
      config
    end
    
  end
  
end
