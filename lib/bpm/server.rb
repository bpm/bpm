require 'rack'
require 'rack-rewrite'
require 'sprockets'
require 'thin'

module BPM

  class Server < ::Rack::Server

    def initialize(project, options={})
      options = default_options.merge(options)
      options[:server] ||= 'thin'
      @project = project
      @mode    = options[:mode] || :debug
      super options
    end

    def self.start(project, options=nil)
      new(project, options).start
    end

    def start
      super
    rescue Errno::EADDRINUSE
      raise BPM::Error, "Port #{options[:Port]} is already in use. Please use --port to specify a different port."
    end

    attr_reader :project
    attr_reader :mode

    def app
      cur_project = @project
      cur_mode    = @mode

      @app ||= ::Rack::Builder.new do
        (use BPM::RackProxy, cur_project, :mode => cur_mode) unless cur_project.preview_proxy.empty?
        use BPM::Rack, cur_project, :mode => cur_mode
        use ::Rack::Rewrite do
          rewrite /^(.*)\/$/, '$1/index.html'
        end
        run ::Rack::Directory.new cur_project.root_path
      end.to_app
    end
  end
end
