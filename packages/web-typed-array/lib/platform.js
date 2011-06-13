// ==========================================================================
// Project:   Web Typed Array
// Copyright: ©2010 Strobe Inc. All rights reserved.
// License:   Licened under MIT license (see __preamble__.js)
// ==========================================================================
/*globals ENV ArrayBuffer */

var supported = false;
switch(ENV.SPADE_PLATFORM.ENGINE) {
  case 'browser':
    supported = 'undefined' !== typeof ArrayBuffer;
    break;
  
  case 'spade':
    supported = true;
}

exports.isSupported = supported;


