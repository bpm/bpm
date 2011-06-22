module BPM::CLI
  class ProjectGenerator < BPM::Generator

    source_root File.join(::BPM::TEMPLATES_DIR, 'project')

    def run
      empty_directory '.'
      FileUtils.cd(destination_root)

      template "LICENSE"
      template "README.md"

      empty_directory "lib"
      empty_directory "tests"

      inside "lib" do
        template "main.js"
      end

      inside "tests" do
        template "main-test.js"
      end
    end

  end
end

