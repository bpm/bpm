require 'sprockets'

module BPM

  # Like the regular directive processor but knows how to resolve directives
  # as module ids, not just file paths
  class DirectiveProcessor < Sprockets::DirectiveProcessor
    
    def process_require_directive(path)
      project      = context.environment.project
      module_path  = project.path_from_module(path)
      path = context.resolve(module_path) rescue path
      context.require_asset(path)
    end
    
    def process_require_tree_directive(path = ".")
      if relative?(path)
        super path
      else
        project     = context.environment.project
        module_path = project.path_from_module path
        root = module_path.sub(/^([^\/]+)\//) do |s|
          project.path_to_package s
        end
                
        context.depend_on(root)

        Dir["#{root}/**/*"].sort.each do |filename|
          if filename == self.file
            next
          elsif File.directory?(filename)
            context.depend_on(filename)
          elsif context.asset_requirable?(filename)
            context.require_asset(filename)
          end
        end
      end
    end
    
  private
    def relative?(path)
      path =~ /^\.($|\.?\/)/
    end
    
  end
  
  # A BPM package-aware asset pipeline.  Asset lookup respects package.json
  # directory configurations as well as loading preprocessors, formats, and
  # postprocessors from the package config.
  #
  class Pipeline < Sprockets::Environment
    
    attr_reader :project
    
    # Pass in the project you want the pipeline to manage.
    def initialize(project)
      @project = project
      project_path = project.root_path

      super project_path

      # use custom directive processor
      %w(text/css application/javascript).each do |kind|
        unregister_processor kind, Sprockets::DirectiveProcessor
        register_processor   kind, BPM::DirectiveProcessor
      end

      # configure search paths
      append_path File.join project_path, 'packages'
      append_path File.dirname project_path
      append_path File.join project_path, 'assets'
    end    
      
  end
  
end
