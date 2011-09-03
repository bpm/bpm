Encoding.default_external = 'UTF-8'

module BPM
  BPM_DIR = ".bpm"
  TEMPLATES_DIR = File.expand_path("../../templates", __FILE__)
  ES5_SHIM_PATH = File.expand_path("../../support/es5-shim.js", __FILE__)

  autoload :CLI,                  'bpm/cli'
  autoload :Credentials,          'bpm/credentials'
  autoload :Local,                'bpm/local'
  autoload :Package,              'bpm/package'
  autoload :Remote,               'bpm/remote'
  autoload :Repository,           'bpm/repository'
  autoload :Project,              'bpm/project'
  autoload :Server,               'bpm/server'
  autoload :Pipeline,             'bpm/pipeline'
  autoload :DirectiveProcessor,   'bpm/pipeline/directive_processor'
  autoload :GeneratedAsset,       'bpm/pipeline/generated_asset'
  autoload :SourceURLProcessor,   'bpm/pipeline/source_url_processor'
  autoload :PluginAsset,          'bpm/pipeline/plugin_asset'
  autoload :PluginContext,        'bpm/pipeline/plugin_context'
  autoload :PackagePipeline,      'bpm/pipeline/package_pipeline'
  autoload :FormatProcessor,      'bpm/pipeline/format_processor'
  autoload :PluginProcessor,      'bpm/pipeline/plugin_processor'

  def self.compile_js(data)
    require 'execjs'
    @es5_shim ||= File.read(ES5_SHIM_PATH)
    ExecJS.compile(@es5_shim+"\n"+data)
  end

end

# The BPM constants need to be defined first
require 'bpm/libgems_ext'
require 'bpm/errors'

