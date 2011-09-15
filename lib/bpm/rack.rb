module BPM
  class Rack
    def initialize(app, project, opts={})
      mode = opts[:mode] || :debug

      @app = app
      @prefix = File.join('/', opts[:url_prefix] || '', 'assets')
      @pipeline = BPM::Pipeline.new(project, mode, true)
    end

    def call(env)
      if env['PATH_INFO'] =~ /^#{@prefix}\/(.+)$/
        env['PATH_INFO'] = $1
        @pipeline.call(env)
      else
        @app.call(env)
      end
    end
  end
end
