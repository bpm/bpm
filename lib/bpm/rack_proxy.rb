require 'net/http'

module BPM
  class RackProxy
    def initialize(app, project, opts={})
      mode = opts[:mode] || :debug

      @app = app
      @proxy = project.bpm_preview_proxy
    end

    def call(env)
      req = ::Rack::Request.new(env)
      method = req.request_method.downcase
      method[0..0] = method[0..0].upcase

      if req.path =~ %r{^#{@proxy['path']}} 
        uri = URI.parse("#{req.scheme}://#{@proxy['host']}#{ ':'+@proxy['port'].to_s if @proxy['port']}#{req.path}")

        proxy_request = Net::HTTP.const_get(method).new("#{uri.path}#{'?' if uri.query}#{uri.query}")

        if proxy_request.request_body_permitted? and req.body
          proxy_request.body_stream = req.body
          proxy_request.content_length = req.content_length
          proxy_request.content_type = req.content_type
        end

        proxy_request['X-Forwarded-For'] = (req.env['X-Forwarded-For'].to_s.split(/, +/) + [req.env['REMOTE_ADDR']]).join(", ")
        proxy_request['X-Requested-With'] = req.env['HTTP_X_REQUESTED_WITH'] if req.env['HTTP_X_REQUESTED_WITH']
        proxy_request['Accept-Encoding'] = req.accept_encoding
        proxy_request['Cookie'] = req.env['HTTP_COOKIE']
        proxy_request['Referer'] = req.referer
        proxy_request.basic_auth *uri.userinfo.split(':') if (uri.userinfo && uri.userinfo.index(':'))

        proxy_response = Net::HTTP.start(uri.host, uri.port, :use_ssl => @proxy['use_ssl'] || false) do |http|
          http.request(proxy_request)
        end

        headers = {}
        proxy_response.each_header do |k,v|
          headers[k] = v unless k.to_s =~ /content-length|transfer-encoding/i
        end

        [proxy_response.code.to_i, headers, [proxy_response.read_body]]
      else
        @app.call(env)
      end
    end
  end
end
