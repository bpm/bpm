require 'sprockets'
require 'execjs'

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

      #ctx["DATA"]  = data
      #ctx["CTX"]   = BPM::PluginContext.new(pkg, module_id)
      plugin_ctx += <<-end_eval
        ; // Safety
        CTX = #{BPM::PluginContext.new(pkg, module_id).to_json};
        CTX.minify = function(body){ return body; };
        DATA = #{data.to_json};
      end_eval

      ctx = ExecJS.compile(plugin_ctx)
      ctx.eval("BPM_PLUGIN.#{self.class.method_name}(DATA, CTX, '#{filepath}')")
    end

  end
end
