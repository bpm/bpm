# 1.0.0.beta.14

  * Switched from therubyracer to execjs, should provide Windows support
  * Don't blow up when encountering invalid vendored packages
  * Better error handling for CLI
  * Added flag for easier debugging
  * Allow packages to be put in vendor directory - Fixes #14
  * Cleanup Package fields
  * Allow packages to be developed in directories without matching names
  * Fix prerelease flag for local packages - Fixes #16
  * Bpm Init no longer changes folder name - Fixes #13
  * Patched Sprockets directive bug

# 1.0.0.beta.13

  * Updated to latest LibGems with bug fixes
  * Improved error messages

# 1.0.0.beta.12

  * Updated to Rack 1.3.2
  * Removed old references to bpm:formats
  * Added wiki link

# 1.0.0.beta.11

  * Moved JSON transport and minifiers into bpm:provides
  * Documentation updates and fixes - Fixes #3
  * Updated options and fixed tests

# 1.0.0.beta.10

  * Updated documentation
  * Switched to GetBPM.org

# 1.0.0.beta.9

  * Fixed bug with init where it would generate broken apps at first.
  * Fixed bug when exceptions are thrown in preview mode that would force you
    to restart the server. Should recover more smoothly now.
  * Other minor bug fixes.
  
# 1.0.0.beta.8

  * First cut at support for formats.
  * Also introduces new requirement for defining transport and format plugins 
    in the package.json.  Now you must use the "bpm:provides" keyword:

New format for defining a format or transport plugin:

      "bpm:provides": {
        "transport": {
          "main": "path/to/transport/plugin"
        },
        
        "format:EXT": {
          "default:mime": "application/javascript",
          "main": "path/to/format/plugin"
        }
      }

# 1.0.0.beta.7

  * fixed bug where local packages that are indirect dependencies of other 
    remote packages could cause bpm to error out unable to find dependencies.
    
  * improved logging slightly
  
# 1.0.0.beta.6 (yanked)

  * bpm now passes a context object with build settings and a minify option
    to plugins - this will allow spade to support string loading.
  
# 1.0.0.beta.5

  * bpm list now shows local dependencies by default.  Use bpm list --remote
    to get remote.
  * better compatibility with npm - "summary" field is optional and "url" is
    mapped to "homepage"
  * fixed some failing unit tests
  * you can now place other projects into a vendor directory and have their 
    packages appear in the local package.  This is useful if you want to 
    import another project which holds multiple packages for development.
  
# 1.0.0.beta.4

  * Fixed issue with compile that would cause exceptions if you deleted the
    global .bpm directory
  * BPM now complains if you load a package whose directory name does not 
    match the name in the package.json (this was causing exceptions in some
    cases)
  * BPM is more whiny now when it tries to load a package with invalid or
    missing package.json.
  * the version stored in the `bpm` key on new projects is a compatible 
    version instead of the actual version.  Right now this means it is frozen
    at 1.0.0
  * merge `bpm new` into `bpm init`.  now this works like git.  If you
    `bpm init` on an existing directory, bpm will try to update it.  If you
    `bpm init` and pass a new path, bpm will create it.
  * now showing version of bpm in bpm help

# 1.0.0.beta.3.pre

  * started changelog
  
