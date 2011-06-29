require 'sprockets'

module BPM

  autoload :DirectiveProcessor,   'bpm/pipeline/directive_processor'
  autoload :GeneratedAsset,       'bpm/pipeline/generated_asset'
  autoload :TransportProcessor,   'bpm/pipeline/transport_processor'
  
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
      
      register_postprocessor 'application/javascript', BPM::TransportProcessor
      

      # configure search paths
      append_path File.join project_path, '.bpm', 'packages'
      append_path File.dirname project_path
      append_path File.join project_path, 'assets'
    end    
      
    # Loads the passed JavaScript file and evals it.  Used for loading 
    # transport and other plugins.
    def js_context_for(path)
      @js_contexts ||= {}
      @js_contexts[path] ||= build_js_context(path)
    end
    
    # Returns an array of all the buildable assets in the current directory.
    # These are the assets that will be built when you compile the project.
    def buildable_assets
      
      # make sure the logical_path can be used to simply build into the 
      # assets directory when we are done
      ret = ['bpm_packages.js', 'bpm_styles.css']
      
      project.local_deps.each do |pkg|
        pkg.load_json
        pkg.pipeline_assets.each do |dir|
          dir_name = pkg.directories[dir] || dir
          dir_name.sub! /^\.?\//, ''
          pkg_root = File.join(pkg.root_path, dir_name)
          Dir[File.join(pkg_root, '**', '*')].each do |fn|
            fn.sub! /^#{Regexp.escape pkg_root}\//, ''
            ret << File.join(pkg.name, dir_name, fn)
          end
        end
      end

      ret.sort.map { |x| find_asset x }.compact
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
    
  private
  
    def build_js_context(path)
      require 'v8'
      
      ctx = V8::Context.new do |ctx|
        ctx['exports'] = {}
        ctx.eval "(function(exports) { #{File.read path} })(exports);"
      end
      
      @js_contexts[path] = ctx
    end
    
        
  end
  
end
