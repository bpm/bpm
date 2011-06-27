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
  
  class GeneratedAsset < Sprockets::BundledAsset

    FORMAT_METHODS = {
      'text/css' => ['css', 'pipeline_css'],
      'application/javascript' => ['lib', 'pipeline_libs']
    }
    
  protected
  
    def dependency_context_and_body
      @dependency_context_and_body ||= build_dependency_context_and_body
    end

  private
  
    def build_dependency_context_and_body

      project = environment.project
      
      # Add in the generated header
      body = <<EOF
/* ===========================================================================
   BPM Static Dependencies
   MANIFEST: #{project.local_deps.map { |x| "#{x.name} (#{x.version})"} * " "}
   This file is generated automatically by the bpm (http://www.bpmjs.org)    
   To use this file, load this file in your HTML head.
   =========================================================================*/

EOF

      # Prime digest cache with data, since we happen to have it
      environment.file_digest(pathname, body)

      # add requires for each depedency to context
      context = blank_context
      context.require_asset(pathname) # start with self
      
      dir_name, dir_method = FORMAT_METHODS[content_type] || ['lib', 'pipeline_libs']
      
      project.local_deps.map do |pkg|
        pkg.load_json
        pkg.send(dir_method).each do |dir|
          dir_name = pkg.directories[dir] || dir 
          search_path = File.expand_path File.join(pkg.root_path, dir_name)
          
          Dir[File.join(search_path, '**', '*')].sort.each do |fn|
            context.depend_on File.dirname(fn)
            context.require_asset(fn) if context.asset_requirable? fn
          end
        end
      end

      return context, body
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
      
    # Detect whenever we are asked to build some of the magic files and swap
    # in a custom asset type that can generate the contents.
    def build_asset(logical_path, pathname, options)
      magic_paths = %w(bpm_packages.js bpm_styles.css).map do |filename|
        File.join project.root_path, 'assets', filename
      end

      if magic_paths.include? pathname.to_s
        BPM::GeneratedAsset.new(self, logical_path, pathname, options)
      else
        super logical_path, pathname, options
      end
    end
        
  end
  
end
