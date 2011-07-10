module BPM
  class ProjectGenerator < BPM::Generator

    source_root File.join(::BPM::TEMPLATES_DIR, 'project')

    def run
      return false if directory_exists?

      empty_directory '.', :verbose => false
      empty_directory 'app'

      create_files

      true
    end

    def company_name
      ENV['COMPANY_NAME'] || "My Company Inc."
    end
    
    private

      def create_files
        template "LICENSE"
        template "README.md"
        template "index.html"
        
        inside 'app' do
          template 'main.js'
        end
      end

      def directory_exists?
        return false unless File.exist? destination_root
        say_status "Directory #{dir_name} already exists", nil, :red
        true
      end

  end
end

BPM.register_generator(:default, :project, BPM::ProjectGenerator)
