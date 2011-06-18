require 'bpm/libgems_ext/libgems'
require 'bpm/libgems_ext/config_file'
require 'bpm/libgems_ext/dependency_installer'
require 'bpm/libgems_ext/installer'
require 'bpm/libgems_ext/spec_fetcher'

# Empty sources to make sure we don't get ones from RubyGems
LibGems.sources = nil

# Reload from new paths
LibGems.load_configuration
