module BPM::CLI
  class ProjectGenerator
    include Thor::Actions

    source_root File.join(TEMPLATES_DIR, 'project')

    attr_reader :name

    def initialize(thor, name, root)
      @thor, @name, @root = thor, name, root

      self.destination_root = root
    end

    def run
      empty_directory '.'
      FileUtils.cd(destination_root)

      template "LICENSE"
      template "README.md"
      template "project.json"

      empty_directory "lib"
      empty_directory "tests"

      inside "lib" do
        template "main.js"
      end

      inside "tests" do
        template "main-test.js"
      end
    end

  private

    def app_const
      name.gsub(/\W|-/, '_').squeeze('_').gsub(/(?:^|_)(.)/) { $1.upcase }
    end

    def current_year
      Time.now.year
    end

    def source_paths
      [File.expand_path('../../templates/project', __FILE__)] +
        @thor.source_paths
    end

    def respond_to?(*args)
      super || @thor.respond_to?(*args)
    end

    def method_missing(name, *args, &blk)
      @thor.send(name, *args, &blk)
    end
  end
end

