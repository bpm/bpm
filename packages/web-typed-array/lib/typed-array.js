// ==========================================================================
// Project:   Web Typed Array
// Copyright: ©2010 Strobe Inc. All rights reserved.
// License:   Licened under MIT license (see __preamble__.js)
// ==========================================================================

var nat = require('./ruby/typed_array');
exports.TypedArray   = nat.TypedArray;
exports.Int8Array    = nat.Int8Array;
exports.Uint8Array   = nat.Uint8Array;
exports.Int16Array   = nat.Int16Array;
exports.Uint16Array  = nat.Uint16Array;
exports.Int32Array   = nat.Int32Array;
exports.Uint32Array  = nat.Uint32Array;
exports.Float32Array = nat.Float32Array;
exports.Float64Array = nat.Float64Array;

exports.Int8Array.BYTES_PER_ELEMENT    = 1;
exports.Uint8Array.BYTES_PER_ELEMENT   = 1;
exports.Int16Array.BYTES_PER_ELEMENT   = 2;
exports.Uint16Array.BYTES_PER_ELEMENT  = 2;
exports.Int32Array.BYTES_PER_ELEMENT   = 4;
exports.Uint32Array.BYTES_PER_ELEMENT  = 4;
exports.Float32Array.BYTES_PER_ELEMENT = 4;
exports.Float64Array.BYTES_PER_ELEMENT = 8;

