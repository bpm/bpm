// ==========================================================================
// Project:   Web Typed Array
// Copyright: ©2010 Strobe Inc. All rights reserved.
// License:   Licened under MIT license (see __preamble__.js)
// ==========================================================================

/**
  On platforms that support it, the FileSystem API provides a way for you 
  to access and navigate files on disk.  FileSystem instances may be provided
  by the system that limits the visible scope of files.
  
  To get the default file system look for the global fileSystem object.  
*/

var nat = require('./ruby/file_system');
var FileSystem;

// ..........................................................
// STAT Object
// 
var Stat = function(nstat) {
  this._nstat = nstat;
};

Stat.prototype = {
  constructor: Stat,

  get size() { return this._nstat.size; },
  get blockSize() { return this._nstat.blksize; },
  get blocks() { return this._nstat.blocks; },
  get mode() { return this._nstat.mode; },

  get uid() { return this._nstat.uid; },
  get gid() { return this._nstat.uid; },

  get device() { return this._nstat.dev; },
  get inode() { return this._nstat.ino; },

  get mtime() { return this._nstat.mtime; },
  get ctime() { return this._nstat.ctime; },
  get atime() { return this._nstat.atime; },

  get isDirectory() { return this._nstat['directory?']; },
  get isFile() { return this._nstat['file?']; },
  get isSymlink() { return this._nstat['symlink?']; },
  get isReadable() { return this._nstat['readable?']; },
  get isWritable() { return this._nstat['writable?']; },
  get isExecutable() { return this._nstat['executable?']; },
  get isSticky() { return this._nstat['sticky?']; }
  
};

// ..........................................................
// FileSystem
// 

function readOnlyError() {
  throw new Error("FileSystem is read only");
}

// We want this to be secure.  hence the reason we do it this way.
FileSystem = function() {
  throw "Invalid constructor";
};

function createFileSystem(root, cwd, readOnly) {

  readOnly = !!readOnly;
  
  // create one off instance
  fs = function() {};
  fs.prototype = FileSystem.prototype;
  fs = new fs();

  fs.SEPARATOR = nat.SEPARATOR;

  
  // Takes an absolute path, removes the root prefix
  function denorm(path) {
    return root==='/' ? path : path.slice(root.length);
  }
  
  // make prefixed
  function norm(path) {
    if(path[0] === fs.SEPARATOR) {
      return nat.expand_path(nat.join_path(root, path));
    } else {
      return nat.expand_path(path, cwd);
    }
  }
    
  fs.__defineGetter__('cwd', function() { return denorm(cwd); });
  fs.__defineSetter__('cwd', function(v) { 
    cwd = norm(v); 
    return denorm(cwd); 
  });
  
  // fs.cwd  = function(path) {
  //   if (path !== undefined) cwd = norm(path);
  //   return denorm(cwd);
  // };
  
  fs.stat = function(path) {
    return new Stat(nat.stat(norm(path)));
  };
  
  fs.open = function(path, opts) {
    if (!opts) opts = {};
    if (!('readable' in opts)) opts.readable = true;
    if (!('writable' in opts) || readOnly) opts.writable = !readOnly;
    if (!('executable' in opts)) opts.executable = false;
    if (!('append' in opts)) opts.append = false;
    if (!('modify' in opts) || opts.append) opts.modify = false;
    return nat.open(norm(path), opts);
  };
  
  fs.exists = function(path) {
    return nat.exists(norm(path));
  };
  
  fs.chroot = function(path, readOnly) {
    path = path===undefined ? cwd : norm(path);
    return createFileSystem(path, path, readOnly);
  };
  
  
  // ..........................................................
  // PATH OPS
  // 
  
  fs.join = function() {
    return nat.join_path(Array.prototype.slice.call(arguments));
  };
    
  fs.split = function(path) {
    return nat.split_path(path);
  };
    
  fs.dirname = function(path) {
    return nat.dirname(path);
  };
  
  fs.basename = function(path, ext) {
    return nat.basename(path, ext);
  };
  
  fs.ext = function(path) {
    return nat.extname(path);
  };
  
  fs.expand = function(path, base) {
    return nat.expand_path(path, base);
  };
  
  fs.glob = function(path) {
    return nat.glob(norm(path)).map(function(x) { return denorm(x); });
  };
  
  // ..........................................................
  // WRITABLE OPS
  // 
  
  fs.mkdir = function(path, mode) {
    if (readOnly) readOnlyError();
    nat.mkdir(norm(path), mode);
    return this;
  };
  
  fs.mkdirs = function(path, mode) {
    if (readOnly) readOnlyError();
    nat.mkdir_p(norm(path), mode);
    return this;
  };
  fs.mkdir_p = fs.mkdirs;
  
  fs.move = function(src, dst) {
    if (readOnly) readOnlyError();
    if (src && src.map) src = src.map(function(s) { return norm(s); });
    else src = norm(src);

    nat.mv(src, norm(dst));
    return this;
  };
  fs.mv = fs.move;

  fs.copy = function(src, dst, opts) {
    if (readOnly) readOnlyError();

    if (src && src.map) src = src.map(function(s) { return norm(s); });
    else src = norm(src);
    
    if (!opts) opts = {};
    if (opts.recursive) nat.cp_r(src, norm(dst));
    else nat.cp(src, norm(dst));

    return this;
  };
  fs.cp = fs.copy;

  fs.remove = function(src, opts) {
    if (readOnly) readOnlyError();

    if (src && src.map) src = src.map(function(s) { return norm(s); });
    else src = norm(src);
    
    if (!opts) opts = {};
    if (opts.force) nat.rm_rf(src);
    else if (opts.recursive) nat.rm_r(src);
    else nat.rm(src)

    return this;
  };
  fs.rm = fs.remove;

  fs.link = function(src, dst, opts) {
    if (readOnly) readOnlyError();

    if (src && src.map) src = src.map(function(s) { return norm(s); });
    else src = norm(src);

    if (!opts) opts = {};
    if (opts.symbolic) nat.ln_s(src, norm(dst));
    else nat.ln(src, norm(dst));

    return this;
  };  
  fs.ln = fs.link;

  return fs;
  
}

exports.FileSystem = FileSystem;
exports.fileSystem = createFileSystem('/', nat.cwd, false);
