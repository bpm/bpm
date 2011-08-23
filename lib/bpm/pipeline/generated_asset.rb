require 'sprockets'
require 'execjs'

module BPM

  class GeneratedAsset < Sprockets::BundledAsset

    FORMAT_METHODS = {
      'text/css' => ['css', 'pipeline_css'],
      'application/javascript' => ['lib', 'pipeline_libs']
    }

    def self.generating_asset
      @generating_asset && @generating_asset.last
    end

    def self.push_generating_asset(asset)
      @generating_asset ||= []
      @generating_asset.push asset
    end

    def self.pop_generating_asset
      @generating_asset && @generating_asset.pop
    end

    def build_settings
      ret = environment.project.build_settings[asset_name]
      (ret && ret['bpm:settings']) || {}
    end

    def minify_as_js
      project = environment.project
      minifier_name = project.minifier_name asset_name
      minifier_name = minifier_name.keys.first if minifier_name

      if minifier_name && content_type == 'application/javascript'
        pkg = project.package_from_name minifier_name
        if pkg.nil?
          raise MinifierNotFoundError.new(minifier_name)
        end
        minifier_plugin_name = pkg.provided_minifier
        if minifier_plugin_name.nil?
          raise MinifierNotFoundError.new(minifier_name)
        end
        plugin_ctx = environment.plugin_js_for minifier_plugin_name

        plugin_ctx += <<-end_eval
          ; // Safety
          CTX.minify = function(body) { return BPM_PLUGIN.minify(body); };
        end_eval

      end
      #Return a default (noop) minifier if none if defined      
      plugin_ctx = "CTX.minify=function(body) { return body; }" unless plugin_ctx;
      plugin_ctx
    end

    def minify_body(data)
      project = environment.project
      minifier_name = project.minifier_name asset_name
      minifier_name = minifier_name.keys.first if minifier_name

      if minifier_name && content_type == 'application/javascript'
        pkg = project.package_from_name minifier_name
        if pkg.nil?
          raise MinifierNotFoundError.new(minifier_name)
        end

        minifier_plugin_name = pkg.provided_minifier
        if minifier_plugin_name.nil?
          raise MinifierNotFoundError.new(minifier_name)
        end

        plugin_ctx = environment.plugin_js_for minifier_plugin_name

        # slice out the header at the top - we don't want the minifier to
        # touch it.
        header   = data.match /^(\/\* ====.+====\*\/)$/m
        if header
          header = header[0] + "\n"
          data   = data[header.size..-1]
        end

        plugin_ctx += <<-end_eval
          ; // Safety
          CTX = #{BPM::PluginContext.new(pkg).to_json};
          CTX.minify = function(body){ return body; };
          DATA = #{data.to_json};
        end_eval

        ctx = ExecJS.compile(plugin_ctx);
        data = ctx.eval("BPM_PLUGIN.minify(DATA, CTX)")

        data = header+data if header
      end
      data
    end

  protected

    def dependency_context_and_body
      @dependency_context_and_body ||= build_dependency_context_and_body
    end

  private

    def build_source
      BPM::GeneratedAsset.push_generating_asset self
      ret = minify super
      BPM::GeneratedAsset.pop_generating_asset
      ret
    end

    def minify(hash)
      return hash if environment.mode == :debug

      hash = environment.cache_hash("#{pathname}:minify", id) do
        data = minify_body hash['source']
        { 'length' => Rack::Utils.bytesize(data),
          'digest' => environment.digest.update(data).hexdigest,
          'source' => data }
      end

      hash['length'] = Integer(hash['length']) if hash['length'].is_a?(String)

      @length = hash['length']
      @digest = hash['digest']
      @source = hash['source']

      hash
    end

    def asset_name
      project = environment.project
      if pathname.to_s.include?(project.assets_root)
        pathname.relative_path_from(Pathname.new(project.assets_root)).to_s
      elsif pathname.to_s.include?(project.preview_root)
        pathname.relative_path_from(Pathname.new(project.preview_root)).to_s
      end
    end

    def build_dependency_context_and_body

      project       = environment.project
      settings = project.build_settings(environment.mode)[asset_name]
      pkgs     = settings.keys.map do |pkg_name|
        if pkg_name == project.name
          project
        else
          project.local_deps.find { |dep| dep.name == pkg_name }
        end
      end.compact

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
        settings[pkg.name].each do |dir|
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
