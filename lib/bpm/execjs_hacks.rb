require 'execjs'

# Hacks for Windows
class ExecJS::ExternalRuntime
  protected
    def exec_runtime(filename)
      output = nil
      # Add //U to force Unicode
      IO.popen("#{@binary} //U #{filename} 2>&1") { |f| output = f.read }
      if $?.success?
        # Windows returns UTF-16LE but we still think it's UTF-8, fix that
        # Should this go before the if?
        output.force_encoding('UTF-16LE').encode('UTF-8')
      else
        raise RuntimeError, output
      end
    end
end
