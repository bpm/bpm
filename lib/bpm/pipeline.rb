require 'sprockets'

module BPM

  class Console
    def log(str)
      shell.say str
    end

    private

    def shell
      @shell ||= Thor::Base.shell.new
    end

  end

  # A BPM package-aware asset pipeline.  Asset lookup respects package.json
  # directory configurations as well as loading preprocessors, formats, and
  # postprocessors from the package config.
  #
  class Pipeline < Sprockets::Environment

    attr_reader :project
    attr_reader :mode
    attr_reader :package_pipelines

    # Pass in the project you want the pipeline to manage.
    def initialize(project, mode = :debug, include_preview = false)

      @project = project
      @mode    = mode
      @plugin_js = {}

      # Create a pipeline for each package.  Will be used for searching.
      @package_pipelines = project.local_deps.map do |pkg|
        BPM::PackagePipeline.new self, pkg
      end
      @package_pipelines << BPM::PackagePipeline.new(self, project)

      project_path = project.root_path

      super project_path

      # Unregister built-in processors.  We want most things served by the
      # pipeline directly to just pass through.  (package pipelines do the
      # processing)
      %w(text/css application/javascript).each do |kind|
        unregister_processor kind, Sprockets::DirectiveProcessor
      end
      unregister_postprocessor 'application/javascript', Sprockets::SafetyColons

      # configure search paths
      append_path project.assets_root
      append_path project.preview_root if include_preview
    end

    # determines the proper pipeline for the path
    def pipeline_for(path)
      return nil if magic_paths.include?(path)
      package_pipelines.find do |cur_pipeline|
        path.to_s[cur_pipeline.package.root_path.to_s]
      end
    end

    def attributes_for(path)
      if path.to_s[File.join(project.root_path, BPM_DIR)] ||  !Pathname.new(path).absolute?
        return super(path)
      end

      pipeline = pipeline_for path
      pipeline ? pipeline.attributes_for(path) : super(path)
    end

    def resolve(logical_path, options={}, &block)

      magic_path = magic_paths.find do |path|
        path =~ /#{Regexp.escape logical_path.to_s}(\..+)?$/
      end

      package_name = logical_path.to_s.sub(/#{Regexp.escape File::SEPARATOR}.+/,'')
      pipeline = package_pipelines.find do |cur_pipeline|
        cur_pipeline.package_name == package_name
      end

      if pipeline && magic_path.nil?
        logical_path = logical_path.to_s[package_name.size+1..-1]
        pipeline.resolve Pathname.new(logical_path), options, &block
      else
        super logical_path, options, &block
      end

    end

    # Detect whenever we are asked to build some of the magic files and swap
    # in a custom asset type that can generate the contents.
    def build_asset(logical_path, pathname, options)
      if magic_paths.include? pathname.to_s
        BPM::GeneratedAsset.new(self, logical_path, pathname, options)
      elsif pipeline = pipeline_for(pathname)
        pipeline.build_asset logical_path, pathname, options
      else
        super logical_path, pathname, options
      end
    end

    # Paths to files that should be built.
    def magic_paths
      @magic_paths ||= build_magic_paths
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

    def plugin_js_for(logical_path)
      @plugin_js[logical_path] ||= build_plugin_js(logical_path)
    end

    # MEGAHAX!!!!
    def find_asset(*)
      asset = super
      # The way BPM is set up we need to call build_source
      asset.send(:build_source) if asset.respond_to?(:build_source, true)
      asset
    end

    # Index is for caching, but it causes us problem,
    # we don't need the caching
    def index
      self
    end

  protected

    def build_magic_paths
      magic_paths = project.buildable_asset_filenames(mode).map do |filename|
        project.assets_root filename
      end

      magic_paths += project.buildable_asset_filenames(mode).map do |filename|
        project.preview_root filename
      end
    end

    # Pass along to package pipelines
    def expire_index!
      super
      @magic_paths = nil
      package_pipelines.each { |pipeline| pipeline.expire_index! }
    end

  private

    def javascript_exception_response(exception)
      expire_index!
      super exception
    end
    
    def css_exception_response(exception)
      expire_index!
      super exception
    end

    def build_plugin_js(logical_path)
      asset = BPM::PluginAsset.new(self, logical_path)
      plugin_text = asset.to_s

      # TODO: Add Console if supported
      # pretty much need the window={} definition otherwise the minifier hash is borked

      return <<-end_eval
        window={};
        if (typeof BPM_PLUGIN === 'undefined') BPM_PLUGIN={};
        #{plugin_text}
      end_eval
    end

  end

end
