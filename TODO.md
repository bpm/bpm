
* you should be able to place other projects into a vendor directory and 
  have their packages appear.

* Multiple format support.  Format processors supplied by dependencies should
  be used to resolve formats.
  
* minify then transport -> this will allow for string loading.

* HTML manifest support [in general we need a way for packages to generate new assets]

* cache-friendly URLs

* HTML files should be able to process as templates using a template plugin

* Should log clearly when fetching from remotes

* Can we use YAML instead of JSON?

* Changing a dependency in a package.json should rebuild all files in preview mode (in case the transport was modified)

* Need to run bpm update before bpm preview for the first time

* combine bpm update and bpm compile - make compile update unless you use --no-update

* "directories" should be optional in package.json - we can infer it.

----------------

# SCENARIOS

## New user with existing app using bpm to manage dependencies

    bpm init .         # creates bpm.json, assets/bpm_libs.js etc.
    
    bpm add sproutcore # updates json & packages with sproutcore
    > Fetching sproutcore...
    > Building bpm_libs.js
    > New library size ~24Kb
    
    # now just load assets/bpm_libs.js to get it all
    
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
    
## User working with unit tests in their app

    # to enable unit testing add a unit testing framework as a dev dependency
    bpm add qunit --dev
    
    # you can also use the generator to introduce a unit test
    bpm gen qunit test foo_test  # creates tests/foo_test.js
    
    # next time you update it will add a assets/app_name/bpm_tests.js file
    # this isn't really necessary though because bpm preview runs this.
    bpm update --no-fetch
    
    # start the preview app and then navigate to the qunit
    bpm preview
    
    # then to run the unit tests - load the qunit viewer...
    visit: http://localhost:4020/assets/qunit 
    
## Developer hacking on a package they intend to redistribute

This works the same way whether you intend to redistribute or not; just put
it inside of a project and name your development dependencies there.  Workflow
is the same as unit testing an app except that the tests should be in the 
package and the tests will be built into `assets/package_name/bpm_tests.js`

## Including a developer package inside of another project

All packages must be developed inside of a project - this means that a package
you intend to distribute via bpm must itself be developed inside of a project.

If you just want to include a developer package just add the project to your 
'vendor' directory.
     