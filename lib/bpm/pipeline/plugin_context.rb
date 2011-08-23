module BPM

  class PluginContext

    attr_reader :moduleId
    attr_reader :package

    def initialize(pkg, module_id=nil)
      @generating_asset = BPM::GeneratedAsset.generating_asset
      @package = pkg.as_json
      @moduleId = module_id
    end

    def minify(body)
      @generating_asset ? @generating_asset.minify_body(body) : body
    end

    def minify_as_js
      @generating_asset ? @generating_asset.minify_as_js : "function(body) { return body;}"
    end

    def settings
      @generating_asset ? @generating_asset.build_settings : {}
    end

    def as_json
      { :package => @package,
        :moduleId => @moduleId,
        :settings => settings }
    end

    def to_json
      as_json.to_json
    end

  end

end
