// ==========================================================================
// Project:   Web File
// Copyright: ©2010 Strobe Inc. All rights reserved.
// License:   Licened under MIT license (see __preamble__.js)
// ==========================================================================

var messages = [
null,
'File Not Found',
'Security Error',
'Operation aborted',
'File not readable',
'Encoding Error'
];

var FileError = function(code) {
  this.code = code;
  this.message = messages[code];
};

FileError.prototype = new Error();
FileError.prototype.constructor = FileError;
FileError.prototype.toString = function() { return this.message; };

FileError.NOT_FOUND_ERR = 1;
FileError.SECURITY_ERR  = 2;
FileError.ABORT_ERR     = 3;
FileError.NOT_READABLE_ERR = 4;
FileError.ENCODING_ERR  = 5;

exports.FileError     = FileError;
exports.FileException = FileError;
