
* Better support for using plugins during builds.  Ideal solution would create a .js file for each plugin and load it in a separate context.  This would  allow each plugin to actually require other dependencies, etc.  This is required to properly support format plugins.

* lookup build dependencies for minification

* Development dependencies
  * Should build into main package.js only in debug mode

* bpm update - updates the frozen dependencies to the latest version

* bpm init - should just create a project.json and the .bpm dir if needed.
  * when reconstructing the .bpm dir look in the packages.js manifest.

* bpm add/remove should automatically create the JS/css files as needed 
  instead of making them part of the template.

* bpm app enable - enables app management by bpm.