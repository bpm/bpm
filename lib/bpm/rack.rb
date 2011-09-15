module BPM
  class Rack
    def initialize(app, project, mode=:debug)
      @app = app
      @pipeline = BPM::Pipeline.new(project, mode, true)
    end

    def call(env)
      if env['PATH_INFO'] =~ %r{^/assets/(.+)$}
        env['PATH_INFO'] = $1
        @pipeline.call(env)
      else
        @app.call(env)
      end
    end
  end
end
