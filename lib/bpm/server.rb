require 'rack'
require 'sprockets'
require 'thin'

module BPM

  class Server < Rack::Server

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

      @app ||= Rack::Builder.new do
        map '/assets' do
          run BPM::Pipeline.new cur_project, cur_mode, true
        end

        map '/' do
          run Rack::Directory.new cur_project.root_path
        end
      end.to_app
    end
  end
end
