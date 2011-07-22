require 'bpm/version'

module BPM
  class InitGenerator < BPM::Generator

    source_root File.join(::BPM::TEMPLATES_DIR, 'init')

    def bpm_version
      BPM::COMPAT_VERSION
    end

    def run
      if File.exist?("package.json")
        convert_package(destination_root)
      else
        template "project.json", "#{name}.json"
      end

      true
    end

    private

      def convert_package(destination_root)
        package = BPM::Package.new(destination_root)
        package.load_json
        new_json = JSON.pretty_generate(package.as_json)
        File.open("#{name}.json", "w"){|f| f.write new_json }
        say "created #{name}.json from package.json"
      end

  end
end

BPM.register_generator(:default, :init, BPM::InitGenerator)
