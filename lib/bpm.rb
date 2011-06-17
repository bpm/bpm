require 'spade/core'
require 'libgems'
require 'libgems_ext'

module Spade
  module Packager
    TEMPLATES_DIR = File.expand_path("../../../templates", __FILE__)

    autoload :CLI,                  'spade/packager/cli'
    autoload :Credentials,          'spade/packager/credentials'
    autoload :Local,                'spade/packager/local'
    autoload :Package,              'spade/packager/package'
    autoload :Remote,               'spade/packager/remote'
    autoload :Repository,           'spade/packager/repository'
    autoload :Version,              'spade/packager/version'
  end
end

