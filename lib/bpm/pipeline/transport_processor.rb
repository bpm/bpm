require 'sprockets'

module BPM
  
  class TransportProcessor < Sprockets::Processor
    
    def evaluate(context, locals)
      project = context.environment.project
      pkg, module_id = project.package_and_module_from_path file
      transport_plugins = pkg.transport_plugins(project)

      # No transport, just return the existing data
      return data if transport_plugins.empty?

      if transport_plugins.size > 1
        # TODO: Maybe make custom error for this
        raise "#{pkg.name} depends on #{transport_plugins.size} packages that define transport plugins. " \
                "Select a plugin by adding a `plugin:transport` property to the package.json"
      end

      project_path = project.root_path.to_s
      project_path << '/' if project_path !~ /\/$/
      filepath = file.sub(/^#{project_path}/,'') # relative file path from project

      transport_path = context.resolve project.path_from_module(transport_plugins.first)
      ctx = context.environment.js_context_for transport_path
      ctx["PACKAGE_INFO"] = pkg.attributes
      ctx["DATA"]         = data
      out = ctx.eval("exports.compileTransport(DATA, PACKAGE_INFO, '#{module_id}', '#{filepath}');")

      out + "\n\n"
    end
    
  end

end
