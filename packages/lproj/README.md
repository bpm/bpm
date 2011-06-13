This package provides infrastructure you need to localize your application. 
You can use this package to automatically load the correct resources for your
application as well as to handle localizing strings.

# Activating Localization

To add localized resources to your application, just create folders in your 
package named {LANG}.lproj where {LANG} is the two-letter language and region
code for your language, such as "en-US" or US english or just "en" for generic
english. Place all of your localized resources for the selected language inside of this directory.

To load resources in your application, first you must load lproj and have it
modify the require() function in your module to make it localization aware.
You must put this line into any file that requires use of localization:

    require('lproj');
    var loc = lproj(require); // makes require localization aware
    
**IMPORTANT** You must assign the lproj require to the 'loc' property on 
require.  Otherwise calling loc will not locate your resource properly.


# Adding Localized Resources

Then, whenever you want to require a resource from your current language, just
use the require.loc() function:

    require.loc('my-app/~lproj/hello');
    
The require.loc() function replaces the '~lproj' in your module path with a 
reference to the proper localized resource.  It will lookup the resource path
using the following algorithm:

  * First it will look for the most specific current language (fr-FR.lproj)
  * Then it will look for the generic language (fr.lproj)
  * Then it will look in the default language (en.lproj)
  * Finally it will look in the 'resources' directory (i.e. non-localized)

Note that in addition, require.async() and require.exists() are automatically
modified to support localization as well.

# Localizing Strings

In addition to localizing resources, lproj makes it easy to localize strings
as well.  To localize a string, you just need to wrap it in a call to loc:

    loc('Localize Me'); // returns a localized version
    
This will lookup the string in a strings file defined in the current package.
A strings file is a special file that appears in the .lproj directory of a 
package mapping unlocalized strings to localized strings.  The strings file 
should appear in your lproj, named 'localized.strings' with each line having
the following format:

    "Localize Me": "I am localized"
  
This will map the unlocalized string "Localize Me" to the localized string "I
am localized".

Note that the loc() method only works because it is uniquely generated for 
EACH module that you load.  This is important because it allows lproj to 
lookup the proper resources for your package.

If you want to get the localized string relative to another module, you can
do so as well with the require.string() method (added when you run lproj()):

    require.string("another-package", "Localize Me");
    // returns the localized value of 'Localize Me' from another-package
    
You can also choose to localize a string using an alternate language by 
passing the language as a second parameter:

    loc('Localize Me', 'fr'); // localize into french from my package
    require.string('another-package', 'Localize Me', 'fr');
    


