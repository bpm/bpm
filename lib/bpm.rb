module BPM
  BPM_DIR = ".bpm"
  TEMPLATES_DIR = File.expand_path("../../../templates", __FILE__)

  autoload :CLI,                  'bpm/cli'
  autoload :Credentials,          'bpm/credentials'
  autoload :Local,                'bpm/local'
  autoload :Package,              'bpm/package'
  autoload :Remote,               'bpm/remote'
  autoload :Repository,           'bpm/repository'
end

require 'libgems'
require 'libgems_ext'
