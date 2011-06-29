class CustomProjectGenerator < BPM::ProjectGenerator

  def require_path
    "#{name}/main.js"
  end

  private

    def create_files
      empty_directory "lib"
      inside "lib" do
        template "main.js"
      end

      template "app.js"
    end

end

BPM.register_generator('custom_generator', :project, CustomProjectGenerator)
