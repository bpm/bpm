/*globals Bundler ENV WINDOWS */

require('rbconfig');
require('fileutils');
require('pathname');
require('yaml');
require('bundler/rubygems_ext');
require('bundler/version');

Bundler = {
  ORIGINAL_ENV: ENV,

  Definition:          require.autoload('bundler/definition'),
  Dependency:          require.autoload('bundler/dependency'),
  Dsl:                 require.autoload('bundler/dsl'),
  UI:                  require.autoload('bundler/ui'),

  WINDOWS: ENV["host_os"].match(/!(msdos|mswin|djgpp|mingw)/),
  FREEBSD: ENV["host_os"].match(/bsd/),
  NULL:    WINDOWS ? "NUL" : "/dev/null"

};

