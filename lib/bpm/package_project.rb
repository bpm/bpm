module BPM
  class PackageProject < Project
    def self.project_file_path(path)
      file = File.join(path, 'package.json')
      File.exist?(file) ? file : nil
    end

    def self.is_project_json?(path)
      json = JSON.load(File.read(path)) rescue nil
      return !!json
    end

    def self.is_project_root?(path)
      !!project_file_path(path)
    end

    def as_json
      json = super
      json.delete("bpm")
      json
    end
  end
end
