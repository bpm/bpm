require 'libgems_ext/libgems'
require 'libgems_ext/config_file'
require 'libgems_ext/dependency_installer'
require 'libgems_ext/installer'
require 'libgems_ext/spec_fetcher'

# Empty sources to make sure we don't get ones from RubyGems
LibGems.sources = nil

# Reload from new paths
LibGems.load_configuration
