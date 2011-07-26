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

    def settings
      @generating_asset ? @generating_asset.build_settings : {}
    end

  end

end
