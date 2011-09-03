require 'sprockets'

module BPM

  # A processor that will invoke a JavaScript-based plugin provided by a
  # package in the system.  The passed method name will be invoked on the
  # plugin.
  class PluginProcessor < Tilt::Template

    def self.with_plugin(plugin_opts, method_name)
      ret = Class.new(self)
      ret.instance_eval do
        @method_name  = method_name
        @plugin_opts  = plugin_opts
      end
      ret
    end

    def self.method_name
      @method_name
    end

    def self.plugin_name
      @plugin_opts["main"]
    end

    def prepare
    end

    def evaluate(context, locals, &block)
      plugin_ctx = context.environment.plugin_js_for self.class.plugin_name
      project = context.environment.project
      pkg, module_id = project.package_and_module_from_path file

      filepath   = file.to_s

      # MEGAHAX!!!
      # This issue that we specifically target only appears when a format
      # is re-provided twice and the re-provider has a transport.
      # This prevents the format from being inappropriately wrapped in
      # the transport.
      if self.class.method_name == 'compileTransport'
        plugin = pkg.find_transport_plugins(project).first
        if !plugin || plugin['main'] != self.class.plugin_name
          return data
        end
      end

      plugin_context = BPM::PluginContext.new(pkg, module_id);
      minifier_js = plugin_context.minify_as_js;

      # CTX.additionalContext is the minifier's execution environment
      plugin_ctx += <<-end_eval
          ; // Safety
          CTX = #{plugin_context.to_json};
          DATA = #{data.to_json};
          CTX.additionalContext=#{minifier_js};
      end_eval

      ctx = BPM.compile_js(plugin_ctx)
      ctx.eval("BPM_PLUGIN.#{self.class.method_name}(DATA, CTX, '#{filepath}')")

    end

  end
end
