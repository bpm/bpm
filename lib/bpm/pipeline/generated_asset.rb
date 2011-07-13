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
      minifier_name = minifier_name.keys.first if minifier_name.is_a? Hash
      
      if minifier_name && content_type == 'application/javascript' 
        
        pkg = project.package_from_name minifier_name
        if pkg.nil?
          raise "Minifier package #{minifier_name} was not found.  Try running bpm update to refresh."
        end
        
        minifier_plugin_name = pkg.plugin_minifier
        plugin_ctx = environment.plugin_context_for minifier_plugin_name
        
        # slice out the header at the top - we don't want the minifier to 
        # touch it.
        lines = body.split "\n"
        header = body.match /^(\/\* ====.+====\*\/)$/m
        if header
          header = header[0] + "\n"
          body   = body[header.size..-1]
        end
        
        V8::C::Locker() do
          plugin_ctx["PACKAGE_INFO"] = pkg.as_json
          plugin_ctx["DATA"]         = body
          body = plugin_ctx.eval("BPM_PLUGIN.minify(DATA, PACKAGE_INFO)")
        end

        body = header+body if header
        
      end
      
      body
    end
    
    def build_dependency_context_and_body

      project = environment.project
      
      case pathname.basename.to_s
      when /^app_/
        pkgs = [project]
      when /^dev_/
        pkgs = project.sorted_development_deps
      else
        pkgs = (environment.mode == :debug) ? project.sorted_deps : project.sorted_runtime_deps
      end

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
   BPM Combined Asset File
   MANIFEST: #{manifest}
   This file is generated automatically by the bpm (http://www.bpmjs.org)    
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
