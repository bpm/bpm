require 'sprockets'

module BPM

  # Defines an asset that represents a build plugin (such as a transport or
  # a minifier.)  The generated asset will include dependencies of the plugin
  # module as well as the module itself.
  class PluginAsset < BPM::GeneratedAsset

    def initialize(environment, module_name)
      pathname = Pathname.new(File.join(environment.project.root_path, BPM_DIR, 'plugins', module_name+'.js'))
      
      unless File.exists? pathname
        FileUtils.mkdir_p File.dirname(pathname)
        FileUtils.touch pathname
      end
      
      super(environment, module_name, pathname, {})
    end
    
  private

    # do not minify plugin assets
    def minify(hash)
      hash
    end
    
    # Note: logical path must be the module
    def plugin_module
      project      = environment.project
      parts        = logical_path.split('/')
      [parts.shift, parts.join('/')]
    end
   
    def build_dependency_context_and_body

      project = environment.project
      # We hardcode this to bpm_libs.js since that's what the plugin should be depending on
      settings = project.build_settings(environment.mode)["bpm_libs.js"]
      pkg_name, module_id = plugin_module
      pkg  = project.package_from_name pkg_name

      # Add in the generated header
      body = ["// BPM PLUGIN: #{logical_path}\n\n"]

      pkg.load_json
      deps = pkg.expanded_deps project
      deps << pkg # always load pkg too

      # Prime digest cache with data, since we happen to have it
      environment.file_digest(pathname, body.join("\n"))

      # add requires for each depedency to context
      context = blank_context

      require_assets(deps, settings, context)

      # require asset itself - this should be included directly in the body
      # we don't want to use any processors
      module_path = context.resolve logical_path
      context.depend_on module_path
      body << "(function(exports) {"
      body << File.read(module_path)
      body << "})(BPM_PLUGIN);\n"
      
      return context, body.join("\n")
    end

  end
end
