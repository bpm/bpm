require 'bpm/version'

module BPM::CLI
  class InitGenerator < BPM::Generator

    source_root File.join(::BPM::TEMPLATES_DIR, 'init')

    def name
      File.basename destination_root
    end
    
    def bpm_version
      BPM::VERSION
    end
    
    def run
      FileUtils.cd(destination_root)

      template "project.json", "#{name}.json"

      empty_directory "static"

      inside "static" do
        template "bpm_packages.js"
        template "bpm_styles.css"
      end
    end

  end
end

