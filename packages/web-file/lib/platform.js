// ==========================================================================
// Project:   Web Typed Array
// Copyright: ©2010 Strobe Inc. All rights reserved.
// License:   Licened under MIT license (see __preamble__.js)
// ==========================================================================
/*globals ENV File */

var supported = false, fs = false;

switch(ENV.SPADE_PLATFORM.ENGINE) {
  case 'browser':
    supported = 'undefined' !== typeof File;
    break;
  
  case 'spade':
    supported = true;
    fs = true;
    break;
}

exports.isSupported = supported;
exports.hasFileSystem = fs; // if true then you can nav filesystem



