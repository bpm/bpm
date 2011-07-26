require 'sprockets'

module BPM
  
  # A Template that will use a format plugin to compile the content
  # Register a subclass of the template with the with_plugin
  class FormatProcessor < BPM::PluginProcessor
    
    def self.with_plugin(ext, plugin_opts)
      ret = super plugin_opts, 'compileFormat'
      ret.instance_eval do
        @extension    = ext
      end
      ret
    end

    def self.extension
      @extension
    end
    
    def self.default_mime_type
      @plugin_opts["mime:default"]
    end    
    
  end
end

    