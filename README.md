bpm - browser packager manager

bpm is a system for managing resource dependencies for client-side browser 
applications.  It is inspired by npm, but has better support for the unique 
needs of browser applications including:
 
  * Supports multiple module loaders (i.e. you can choose RequireJS, spade or 
    even no loader at all)
  * Handles non-JS assets such as CSS and images. (Support for SCSS/Sass 
    coming soon)  
  * Can autocompile other languages such as CoffeeScript.

bpm also implements a basic build system that generates cache-optimized 
assets.

Finally, bpm is based on the rubygems library.  Although you don't need to 
know any ruby to use bpm, this means that we also benefit from nearly 10 years
of lessons learned to jump start bpm.

# Workflow Quick Start

Once you have bpm installed (see below), create a demo app like so:

    bpm init my_app
    cd my_app
    
Then add jquery as a dependency:

    bpm add jquery
    
This will create a file called `assets/bpm_libs` which will include
jquery.  You can then create an index.html and reference that js.  Everytime
you add a dependency, it will be based into this JS file . 

Note that there is also a CSS file at `assets/bpm_styles.css` - we do the same
thing there.

# Installing

Install via RubyGems:

  `gem install bpm --pre`

When we release, bpm will be also be available via PKG and EXE installers as well.

# Current Development Status

Beta.  You should be able to work the basic system, but some features are 
still incomplete.

# Additional Documentation

https://github.com/bpm/bpm/wiki
