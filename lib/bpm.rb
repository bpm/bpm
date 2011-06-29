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

end

require 'bpm/libgems_ext'
require 'bpm/pipeline'

