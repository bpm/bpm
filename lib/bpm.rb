# Included vendored sprockets
$:.unshift File.expand_path('../../vendor/sprockets/lib', __FILE__)

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
  autoload :TransportProcessor,   'bpm/pipeline/transport_processor'
  autoload :SourceURLProcessor,   'bpm/pipeline/source_url_processor'
  autoload :PluginAsset,          'bpm/pipeline/plugin_asset'
end

# The BPM constants need to be defined first
require 'bpm/libgems_ext'
require 'bpm/errors'

