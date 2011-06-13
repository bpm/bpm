// ==========================================================================
// Project:   Web Typed Array
// Copyright: ©2010 Strobe Inc. All rights reserved.
// License:   Licened under MIT license (see __preamble__.js)
// ==========================================================================
/*globals ENV ArrayBuffer ArrayBufferView DataView TypedArray Int8Array Uint8Array Int16Array Uint16Array Int32Array Uint32Array Float32Array Float64Array */

if (!require('./platform').isSupported) {
  throw new Error('Typed arrays are not supported on this platform');
}

var exp;

// browser either supports it or doesn't.
if (ENV.SPADE_PLATFORM.ENGINE !== 'browser') {
  ArrayBuffer = require('./array-buffer').ArrayBuffer;
  
  exp = require('./array-buffer-view');
  ArrayBufferView = exp.ArrayBufferView;
  DataView        = exp.DataView;
  
  exp = require('./typed-array');
  TypedArray   = exp.TypedArray;
  Int8Array    = exp.Int8Array;
  Uint8Array   = exp.Uint8Array;
  Int16Array   = exp.Int16Array;
  Uint16Array  = exp.Uint16Array;
  Int32Array   = exp.Int32Array;
  Uint32Array  = exp.Uint32Array;
  Float32Array = exp.Float32Array;
  Float64Array = exp.Float64Array;
}

