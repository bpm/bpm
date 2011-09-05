Encoding.default_external = 'UTF-8'

module BPM
  BPM_DIR = ".bpm"
  TEMPLATES_DIR = File.expand_path("../../templates", __FILE__)

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

  @@show_deprecations = false
  @@deprecation_count = 0

  def self.show_deprecations
    @@show_deprecations
  end

  def self.show_deprecations=(val)
    @@show_deprecations = val
  end

  def self.deprecation_count
    @@deprecation_count
  end

  def self.deprecation_warning(message)
    if show_deprecations
      warn "[DEPRECATION] #{message}"
    else
      @@deprecation_count += 1
    end
  end

end

# The BPM constants need to be defined first
require 'bpm/libgems_ext'
require 'bpm/errors'

