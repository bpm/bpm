// ==========================================================================
// Project:   Web Typed Array
// Copyright: ©2010 Strobe Inc. All rights reserved.
// License:   Licened under MIT license (see __preamble__.js)
// ==========================================================================
/*globals ENV File Blob FileReader FileReaderSync FileSystem fileSystem FileWriter FileWriterSync */

if (!require('./platform').isSupported) {
  throw new Error('File API is not supported on this platform');
}

var exp;

// browser either supports it or doesn't.
if (ENV.SPADE_PLATFORM.ENGINE !== 'browser') {
  exp = require('./file');
  Blob = exp.Blob;
  File = exp.File;
  
  exp = require('./file-reader');
  FileReader = exp.FileReader;
  FileReaderSync = exp.FileReaderSync;

  exp = require('./file-writer');
  FileWriter = exp.FileWriter;
  FileWriterSync = exp.FileWriterSync;
  
  exp = require('./file-system');
  FileSystem = exp.FileSystem;
  fileSystem = exp.fileSystem;
}



