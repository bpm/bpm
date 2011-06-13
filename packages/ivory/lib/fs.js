// ==========================================================================
// Project:   Ivory
// Copyright: ©2010 Strobe Inc. All rights reserved.
// License:   Licened under MIT license
// ==========================================================================

// borrows from node.js
var Buffer  = require('./buffer').Buffer;

var util = require('./util');

var binding = require('./ruby/fs');
var constants = require('./ruby/constants');
var fs = exports;

for(var key in constants) fs[key] = constants[key];

fs.STDIN = binding.stdin;
fs.STDOUT = binding.stdout;

fs.Stats = binding.Stats;

fs.Stats.prototype._checkModeProperty = function(property) {
  return ((this.mode & constants.S_IFMT) === property);
};

fs.Stats.prototype.isDirectory = function() {
  return this._checkModeProperty(constants.S_IFDIR);
};

fs.Stats.prototype.isFile = function() {
  return this._checkModeProperty(constants.S_IFREG);
};

fs.Stats.prototype.isBlockDevice = function() {
  return this._checkModeProperty(constants.S_IFBLK);
};

fs.Stats.prototype.isCharacterDevice = function() {
  return this._checkModeProperty(constants.S_IFCHR);
};

fs.Stats.prototype.isSymbolicLink = function() {
  return this._checkModeProperty(constants.S_IFLNK);
};

fs.Stats.prototype.isFIFO = function() {
  return this._checkModeProperty(constants.S_IFIFO);
};

fs.Stats.prototype.isSocket = function() {
  return this._checkModeProperty(constants.S_IFSOCK);
};

fs.readFile = function(path, encoding_) {
  var encoding = typeof(encoding_) === 'string' ? encoding_ : null;
  var callback = arguments[arguments.length - 1];
  if (typeof(callback) !== 'function') callback = null;
  return binding.readFile(path, encoding, callback);
};


// Used by binding.open and friends
function stringToFlags(flag) {
  // Only mess with strings
  if (typeof flag !== 'string') {
    return flag;
  }
  switch (flag) {
    case 'r':
      return constants.O_RDONLY;

    case 'r+':
      return constants.O_RDWR;

    case 'w':
      return constants.O_CREAT | constants.O_TRUNC | constants.O_WRONLY;

    case 'w+':
      return constants.O_CREAT | constants.O_TRUNC | constants.O_RDWR;

    case 'a':
      return constants.O_APPEND | constants.O_CREAT | constants.O_WRONLY;

    case 'a+':
      return constants.O_APPEND | constants.O_CREAT | constants.O_RDWR;

    default:
      throw new Error('Unknown file open flag: ' + flag);
  }
}

function noop() {}

// Yes, the follow could be easily DRYed up but I provide the explicit
// list to make the arguments clear.

fs.close = function(fd, callback) {
  binding.close(fd, callback);
};

fs.open = function(path, flags, mode_, callback) {
  var mode = (typeof(mode_) === 'number' ? mode_ : 0666);
  var callback_ = arguments[arguments.length - 1];
  callback = (typeof(callback_) == 'function' ? callback_ : null);

  return binding.open(path, stringToFlags(flags), mode, callback);
};

fs.read = function(fd, buffer, offset, length, position, callback) {
  return binding.read(fd, buffer, offset, length, position, callback);
};

fs.write = function(fd, buffer, offset, length, position, callback) {
  return binding.write(fd, buffer, offset, length, position, callback);
};

fs.rename = function(oldPath, newPath, callback) {
  return binding.rename(oldPath, newPath, callback);
};

fs.truncate = function(fd, len, callback) {
  return binding.truncate(fd, len, callback);
};

fs.rmdir = function(path, callback) {
  return binding.rmdir(path, callback);
};

fs.fdatasync = function(fd, callback) {
  return binding.fdatasync(fd, callback);
};

fs.fsync = function(fd, callback) {
  return binding.fsync(fd, callback);
};

fs.mkdir = function(path, mode, callback) {
  return binding.mkdir(path, mode, callback);
};

fs.mkdir_p = function(path, mode, callback) {
  return binding.mkdir_p(path, mode, callback);
};

fs.sendfile = function(outFd, inFd, inOffset, length, callback) {
  return binding.sendfile(outFd, inFd, inOffset, length, callback);
};

fs.readdir = function(path, callback) {
  return binding.readdir(path, callback);
};

fs.readdir_p = function(path, callback) {
  if (!fs.exists(path)) {
    if (callback) callback(null, []);
    else return [];
  } else return fs.readdir(path, callback);
};

fs.fstat = function(fd, callback) {
  return binding.fstat(fd, callback);
};

fs.lstat = function(path, callback) {
  return binding.lstat(path, callback);
};

fs.stat = function(path, callback) {
  return binding.stat(path, callback);
};

fs.readlink = function(path, callback) {
  return binding.readlink(path, callback);
};

fs.symlink = function(destination, path, callback) {
  return binding.symlink(destination, path, callback);
};

fs.link = function(srcpath, dstpath, callback) {
  return binding.link(srcpath, dstpath, callback);
};

fs.unlink = function(path, callback) {
  return binding.unlink(path, callback);
};

fs.chmod = function(path, mode, callback) {
  return binding.chmod(path, mode, callback);
};

fs.chown = function(path, uid, gid, callback) {
  return binding.chown(path, uid, gid, callback);
};

function writeAll(fd, buffer, offset, length, callback) {
  // write(fd, buffer, offset, length, position, callback)
  fs.write(fd, buffer, offset, length, offset, function(writeErr, written) {
    if (writeErr) {
      fs.close(fd, function() {
        if (callback) callback(writeErr);
      });
    } else {
      if (written === length) {
        fs.close(fd, callback);
      } else {
        writeAll(fd, buffer, offset + written, length - written, callback);
      }
    }
  });
}

fs.writeFile = function(path, data, encoding_, callback) {
  var encoding = (typeof(encoding_) == 'string' ? encoding_ : 'utf8');
  var callback_ = arguments[arguments.length - 1];
  callback = (typeof(callback_) == 'function' ? callback_ : null);
  binding.writeFile(path, data, encoding, callback);
};

// Stat Change Watchers

var statWatchers = {};

fs.watchFile = function(filename) {
  var stat;
  var options;
  var listener;

  if ('object' == typeof arguments[1]) {
    options = arguments[1];
    listener = arguments[2];
  } else {
    options = {};
    listener = arguments[1];
  }

  if (options.persistent === undefined) options.persistent = true;
  if (options.interval === undefined) options.interval = 0;

  if (statWatchers[filename]) {
    stat = statWatchers[filename];
  } else {
    statWatchers[filename] = new binding.StatWatcher();
    stat = statWatchers[filename];
    stat.start(filename, options.persistent, options.interval);
  }
  stat.addListener('change', listener);
  return stat;
};

fs.unwatchFile = function(filename) {
  var stat;
  if (statWatchers[filename]) {
    stat = statWatchers[filename];
    stat.stop();
    statWatchers[filename] = undefined;
  }
};

fs.exists = function(path, callback) {
  var ret = binding.exists(path);
  if (callback) callback(false, ret);
  return ret ;
};

