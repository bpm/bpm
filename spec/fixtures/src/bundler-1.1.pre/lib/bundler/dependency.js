require('rubygems/dependency');
require('bundler/shared_helpers');
require('bundler/rubygems_ext');

Bundler.Dependency = {
  autorequire: false,
  groups: [],
  platforms: [],
  
  PLATFORM_MAP = {
    'ruby': 'RUBY',
    'ruby_18': 'RUBY'
  }
} ;

