require 'sprockets'

module BPM
  
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

    def build_source
      minify super
    end

    def minify(body)
      return body if environment.mode == :debug
      project = environment.project
      minifier_name = project.minifier_name
      if minifier_name && content_type == 'application/javascript' 
        pkg = project.package_from_name minifier_name
        minifier_plugin_name = pkg.minifier_plugins(project).first
        plugin_ctx = environment.plugin_context_for minifier_plugin_name
        
        V8::C::Locker() do
          plugin_ctx["PACKAGE_INFO"] = pkg.attributes
          plugin_ctx["DATA"]         = body
          body = plugin_ctx.eval("BPM_PLUGIN.minify(DATA, PACKAGE_INFO)")
        end
      end
      
      body
    end
    
    def build_dependency_context_and_body

      project = environment.project
      pkgs = pathname.to_s =~ /app_/ ? [project] : project.sorted_deps
      if pkgs.size > 0
        manifest = pkgs.sort { |a,b| a.name <=> b.name } 
        manifest = manifest.map do |x| 
          "#{x.name} (#{x.version})"
        end.join " "
      else
        manifest = "(none)"
      end

      # Add in the generated header
      body = <<EOF
/* ===========================================================================
   BPM Static Dependencies
   MANIFEST: #{manifest}
   This file is generated automatically by the bpm (http://www.bpmjs.org)    
   To use this file, load this file in your HTML head.
   =========================================================================*/

EOF

      # Prime digest cache with data, since we happen to have it
      environment.file_digest(pathname, body)

      # add requires for each depedency to context
      context = blank_context
      context.require_asset(pathname) # start with self

      if pathname.to_s =~ /_tests\.js$/
        dir_name, dir_method = ['tests', 'pipeline_tests']
      else
        dir_name, dir_method = FORMAT_METHODS[content_type] || ['lib', 'pipeline_libs']
      end

      pkgs.map do |pkg|
        pkg.load_json
        pkg.send(dir_method).each do |dir|
          dir_names = Array(pkg.directories[dir] || dir)
          dir_names.each do |dir_name|
            search_path = File.expand_path File.join(pkg.root_path, dir_name)

            Dir[File.join(search_path, '**', '*')].sort.each do |fn|
              context.depend_on File.dirname(fn)
              context.require_asset(fn) if context.asset_requirable? fn
            end
          end
        end
      end

      return context, body
    end

  end
end
