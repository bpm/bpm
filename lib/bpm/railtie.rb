module BPM
  class Railtie < Rails::Railtie
    config.preview_bpm_app = false
    config.bpm_app_dir = 'app'

    initializer "bpm_rails.insert_bpm_pipeline" do |app|
      if app.config.preview_bpm_app
        path = app.config.bpm_app_dir
        full_path = File.join(app.paths['public'].first, app.config.bpm_app_dir)
        project = BPM::Project.new(full_path)
        app.config.middleware.insert_before 'ActionDispatch::Static', 'BPM::Rack', project, :mode => :debug, :url_prefix => path
      end
    end
  end
end
