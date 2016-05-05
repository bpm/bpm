require 'net/http'

module BPM
  class RackProxy
    def initialize(app, project, opts={})
      mode = opts[:mode] || :debug

      @app = app
      @proxy = project.preview_proxy
    end

    def call(env)
      if env["PATH_INFO"] =~ /^\/#{@proxy['path']}/
        # puts @app.inspect
        request = ::Rack::Request.new(env)

        port = @proxy['port'] || (@proxy['use_ssl'] ? 443 : 80)
        
        http = Net::HTTP.new(@proxy['server'], port)
        http.use_ssl = @proxy['use_ssl'] || false
        
        @response = http.start { |http|
          path = "#{env["REQUEST_PATH"]}?#{env["QUERY_STRING"]}"
          req = ::Net::HTTP::Get.new(path)
          http.request(req)        
        }

        [@response.code, {"Content-Type" => @response.content_type}, [@response.body]]  
      else
        @app.call(env)
      end
    end
  end
end
