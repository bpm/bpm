require 'rack'
require 'sprockets'

module BPM

  class Trial
    
    def initialize(app)
      @app = app
    end
    
    def call(env)
      puts env.to_json
      ret = @app.call(env)
      puts "RET = \n  #{ret * "\n  "}"
      ret
    end
  end
  
  class Server < Rack::Server
    
    def initialize(project, options=nil)
      @project = project
      super options
    end
    
    def self.start(project, options=nil)
      new(project, options).start
    end
    
    attr_reader :project
    
    def app
      cur_project = @project

      @app ||= Rack::Builder.new do
        map '/assets' do
          run BPM::Trial.new(BPM::Pipeline.new cur_project)
        end
      end.to_app
    end
    
  end
end
