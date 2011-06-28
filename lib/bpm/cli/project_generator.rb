module BPM::CLI
  class ProjectGenerator < BPM::Generator

    source_root File.join(::BPM::TEMPLATES_DIR, 'project')

    def run
      if File.exist? destination_root
        say_status "Directory #{dir_name} already exists", nil, :red
        return false
      end

      empty_directory '.', :verbose => false

      template "LICENSE"
      template "README.md"
      template "index.html"
      template "app.js"

      empty_directory "lib"
      empty_directory "tests"

      inside "lib" do
        template "main.js"
      end

      inside "tests" do
        template "main-test.js"
      end

      true
    end

  end
end

