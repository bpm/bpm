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
    def initialize(project, mode = :debug, include_preview = false)
      
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
      #register_postprocessor 'application/javascript', BPM::SourceURLProcessor

      # This gunks things up. I'm not a fan - PDW
      unregister_postprocessor 'application/javascript', Sprockets::SafetyColons

      # configure search paths
      append_path File.join project_path, '.bpm', 'packages'
      append_path File.dirname project_path
      append_path project.assets_root
      append_path project.preview_root if include_preview
    end    
      
    def plugin_context_for(module_id)
      @plugin_contexts[module_id] ||= build_plugin_context(module_id)
    end
    
    # Returns an array of all the buildable assets in the current directory.
    # These are the assets that will be built when you compile the project.
    def buildable_assets
      
      # make sure the logical_path can be used to simply build into the 
      # assets directory when we are done
      ret = project.buildable_asset_filenames mode
      
      # Add in the static assets that we just need to copy
      project.build_settings(mode).each do |target_name, opts|
        next unless opts.is_a? Array
        opts.each do |dir_name| 
          
          dep = project.local_deps.find { |dep| dep.name == target_name }
          dep = project if project.name == target_name
          
          dir_paths = File.join(dep.root_path, dir_name)
          if File.directory? dir_paths
            dir_paths = Dir[File.join(dir_paths, '**', '*')]
          else
            dir_paths = [dir_paths]
          end

          dir_paths.each do |dir_path|
            if File.exist?(dir_path) && !File.directory?(dir_path)
              ret << File.join(target_name, dir_path[dep.root_path.size+1..-1])
            end
          end
        end
      end

      ret.sort.map { |x| find_asset x }.compact
    end
    
    # Detect whenever we are asked to build some of the magic files and swap
    # in a custom asset type that can generate the contents.
    def build_asset(logical_path, pathname, options)
      magic_paths = project.buildable_asset_filenames(mode).map do |filename|
        project.assets_root filename
      end

      magic_paths += project.buildable_asset_filenames(mode).map do |filename|
        project.preview_root filename
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
