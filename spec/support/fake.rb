require 'rack'
require 'logger'
require 'timeout'
require 'net/http'

module SpecHelpers
  class Fake
    def call(env)
      [200, {"Content-Type" => "text/plain"}, ["Hello world!"]]
    end
  end

  def start_fake(app)
    uri   = URI.parse("http://localhost:9292/")
    raise "Server already running on 9292" if uri_active?(uri)

    @fake_pid = Process.fork do
      logger = Logger.new(StringIO.new)
      Rack::Handler::WEBrick.run(app, :Port => 9292, :Logger => logger, :AccessLog => [[logger, WEBrick::AccessLog::COMBINED_LOG_FORMAT]])
    end
    ready = false
    until ready
      if uri_active?(uri)
        ready = true
      else
        print "-" if ENV["VERBOSE"]
      end
    end
  end

  def stop_fake
    Process.kill(9, @fake_pid) if @fake_pid
  end

  private

    def uri_active?(uri)
      begin
        timeout(1) do
          Net::HTTP.get_response(uri)
        end
        true
      rescue Timeout::Error, SystemCallError
        false
      end
    end
end

