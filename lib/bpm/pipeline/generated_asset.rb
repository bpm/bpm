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

    def build_dependency_context_and_body

      project = environment.project
      if project.local_deps.size > 0
        manifest = project.local_deps.map do |x| 
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

      dir_name, dir_method = FORMAT_METHODS[content_type] || ['lib', 'pipeline_libs']

      project.local_deps.map do |pkg|
        pkg.load_json
        pkg.send(dir_method).each do |dir|
          dir_name = pkg.directories[dir] || dir 
          search_path = File.expand_path File.join(pkg.root_path, dir_name)

          Dir[File.join(search_path, '**', '*')].sort.each do |fn|
            context.depend_on File.dirname(fn)
            context.require_asset(fn) if context.asset_requirable? fn
          end
        end
      end

      return context, body
    end

  end
end
