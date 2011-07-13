require 'sprockets'
require 'v8'

module BPM

  class Console
    def log(str)
      puts str
    end
  end
  
  # A BPM package-aware asset pipeline.  Asset lookup respects package.json
  # directory configurations as well as loading preprocessors, formats, and
  # postprocessors from the package config.
  #
  class Pipeline < Sprockets::Environment
    
    attr_reader :project
    attr_reader :mode
    
    # Pass in the project you want the pipeline to manage.
    def initialize(project, mode = :debug)
      @project = project
      @mode    = mode
      @plugin_contexts = {}
      
      project_path = project.root_path

      super project_path

      # use custom directive processor
      %w(text/css application/javascript).each do |kind|
        unregister_processor kind, Sprockets::DirectiveProcessor
        register_processor   kind, BPM::DirectiveProcessor
      end

      register_postprocessor 'application/javascript', BPM::TransportProcessor

      # This gunks things up. I'm not a fan - PDW
      unregister_postprocessor 'application/javascript', Sprockets::SafetyColons

      # configure search paths
      append_path File.join project_path, '.bpm', 'packages'
      append_path File.dirname project_path
      append_path File.join project_path, 'assets'
    end    
      
    def plugin_context_for(module_id)
      @plugin_contexts[module_id] ||= build_plugin_context(module_id)
    end
    
    # Returns an array of all the buildable assets in the current directory.
    # These are the assets that will be built when you compile the project.
    def buildable_assets
      
      # make sure the logical_path can be used to simply build into the 
      # assets directory when we are done
      ret = ['bpm_packages.js', 'bpm_styles.css', "bpm_tests.js",
              "#{project.name}/app_package.js", "#{project.name}/app_styles.css", "#{project.name}/app_tests.js"]
      
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

      magic_paths += %w(app_package.js app_styles.css app_tests.js).map do |filename|
        File.join project.root_path, 'assets', project.name, filename
      end
      
      if magic_paths.include? pathname.to_s
        BPM::GeneratedAsset.new(self, logical_path, pathname, options)
      else
        super logical_path, pathname, options
      end
    end
    
  private
  
    def build_plugin_context(module_id)
      asset = BPM::PluginAsset.new(self, module_id)
      plugin_text = asset.to_s
      
      ctx = nil
      V8::C::Locker() do
        ctx = V8::Context.new do |ctx|
          ctx['window'] = ctx # make browser-like environment
          ctx['console'] = BPM::Console.new
          
          ctx['BPM_PLUGIN'] = {}
          ctx.eval plugin_text
        end
      end
      
      ctx
    end
        
  end
  
end
