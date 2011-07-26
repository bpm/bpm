require 'sprockets'

module BPM
  
  # A sub-environment created for each package in the project.  Requests for
  # individual assets will usually end up going through one of these 
  # instances.  This allows each package to have its own set of processors
  # for each file.
  class PackagePipeline < Sprockets::Environment
    
    attr_reader :pipeline, :package
    
    def shell
      @shell ||= Thor::Base.shell.new
    end
    
    def initialize(pipeline, package)
      @pipeline = pipeline
      @package  = package
      
      super package.root_path
      
      %w(text/css application/javascript).each do |kind|
        unregister_processor kind, Sprockets::DirectiveProcessor
        register_processor   kind, BPM::DirectiveProcessor
      end

      # This gunks things up. I'm not a fan - PDW
      unregister_postprocessor 'application/javascript', Sprockets::SafetyColons

      package.used_formats(project).each do |ext, opts|
        register_engine ".#{ext}", BPM::FormatProcessor.with_plugin(ext,opts)
      end

      package.used_preprocessors(project).each do |opts|
        register_preprocessor opts['mime'], 
          BPM::PluginProcessor.with_plugin(opts, 'preprocess')
      end

      package.used_postprocessors(project).each do |opts|
        register_postprocessor opts['mime'], 
          BPM::PluginProcessor.with_plugin(opts, 'postprocess')
      end

      opts = package.used_transports(project)
      raise TooManyTransportsError(package) if opts.size>1
      if opts.size>0
        register_postprocessor 'application/javascript', 
          BPM::PluginProcessor.with_plugin(opts.first, 'compileTransport')
      end

      append_path package.root_path
    end
    
    def package_name
      package.name
    end
    
    def project
      pipeline.project
    end
    
    def mode
      pipeline.mode
    end
    
    def plugin_context_for(logical_path)
      pipeline.plugin_context_for logical_path
    end

  end
end
