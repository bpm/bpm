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

      if File.exist?("package.json")
        convert_package(destination_root)
      else
        template "project.json", "#{name}.json"
      end

      empty_directory "assets"

      inside "assets" do
        template "bpm_packages.js"
        template "bpm_styles.css"
      end
    end

    private

      def convert_package(destination_root)
        package = BPM::Package.new(destination_root)
        package.load_json
        File.open("#{name}.json", "w") do |f|
          f.write JSON.pretty_generate(package.as_json)
        end
        puts "created #{name}.json from package.json"
      end

  end
end

