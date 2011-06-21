module BPM
  BPM_DIR = ".bpm"
  TEMPLATES_DIR = File.expand_path("../../templates", __FILE__)

  autoload :CLI,                  'bpm/cli'
  autoload :Credentials,          'bpm/credentials'
  autoload :Local,                'bpm/local'
  autoload :Package,              'bpm/package'
  autoload :Remote,               'bpm/remote'
  autoload :Repository,           'bpm/repository'
  autoload :Generator,            'bpm/generator'
  autoload :Project,              'bpm/project'
end

require 'bpm/libgems_ext'
