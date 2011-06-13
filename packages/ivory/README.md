# Ivory - A basic filesystem 

Ivory is a basic filesystem API for JS.  It is based mostly on the node.js 
API but internally uses a ruby binding for use with the spade runtime.

Currently Ivory is considered unstable.  The API can change at any time.  In
general we try to keep it close to node.js.

## Usage

You can use the API just like the node.js format:

    var fs = require('ivory/fs');
    
You can also import the entire API into a global context.

    require('ivory/fs');
    $fs.open(..);
    
