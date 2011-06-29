require 'sprockets'

module BPM
  
  class TransportProcessor < Sprockets::Processor
    
    def evaluate(context, locals)
      project = context.environment.project
      pkg, module_id = project.package_and_module_from_path file
      transport_plugins = pkg.transport_plugins(project)
      
      if transport_plugins.size > 1
        raise "#{pkg.name} depends on #{transport_plugins.size} packages that define transport plugins.  Select a plugin by adding a `plugin:transport` property to the package.json"
      elsif transport_plugins.size == 1
        transport_module = transport_plugins.first
        
        transport_path   = context.resolve project.path_from_module(transport_module)

        ctx = context.environment.js_context_for transport_path
        ctx["PACKAGE_INFO"] = pkg.attributes
        ctx["DATA"]         = data
        wrapped = ctx.eval "exports.compileTransport(DATA, PACKAGE_INFO, '#{module_id}');"

        wrapped
      else
        data
      end
    end
    
  end

end
