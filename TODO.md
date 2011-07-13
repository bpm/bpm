
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

----------------

# SCENARIOS

## New user with existing app using bpm to manage dependencies

    bpm init .         # creates bpm.json, assets/bpm_packages.js etc.
    
    bpm add sproutcore # updates json & packages with sproutcore
    > Fetching sproutcore...
    > Building bpm_packages.js
    > New library size ~24Kb
    
    # now just load assets/bpm_packages.js to get it all
    
    bpm remove sproutcore # updates json & packages to remove...
    ...
    
## User migrates to use bpm to manage their app as well

    bpm init --app  # enables app management, creates app dir for JS
    
    # now just make your index.html load assets/app_name/app_package.js
    
    bpm preview     # returns auto-compiled resources while working.
                    # also we could publish a rails plugin that bakes in to 
                    # rails app
    
    bpm compile     # generates a built app when you are ready to go to prod
                    # maybe should build the entire thing into a different 
                    # loc?
                    
    bpm update      # invoke if you modify the bpm.json to update settings
    
    
     