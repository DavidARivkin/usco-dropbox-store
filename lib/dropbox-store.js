require=(function e(t,n,r){function s(o,u){if(!n[o]){if(!t[o]){var a=typeof require=="function"&&require;if(!u&&a)return a(o,!0);if(i)return i(o,!0);throw new Error("Cannot find module '"+o+"'")}var f=n[o]={exports:{}};t[o][0].call(f.exports,function(e){var n=t[o][1][e];return s(n?n:e)},f,f.exports,e,t,n,r)}return n[o].exports}var i=typeof require=="function"&&require;for(var o=0;o<r.length;o++)s(r[o]);return s})({1:[function(require,module,exports){

},{}],2:[function(require,module,exports){
// shim for using process in browser

var process = module.exports = {};

process.nextTick = (function () {
    var canSetImmediate = typeof window !== 'undefined'
    && window.setImmediate;
    var canPost = typeof window !== 'undefined'
    && window.postMessage && window.addEventListener
    ;

    if (canSetImmediate) {
        return function (f) { return window.setImmediate(f) };
    }

    if (canPost) {
        var queue = [];
        window.addEventListener('message', function (ev) {
            var source = ev.source;
            if ((source === window || source === null) && ev.data === 'process-tick') {
                ev.stopPropagation();
                if (queue.length > 0) {
                    var fn = queue.shift();
                    fn();
                }
            }
        }, true);

        return function nextTick(fn) {
            queue.push(fn);
            window.postMessage('process-tick', '*');
        };
    }

    return function nextTick(fn) {
        setTimeout(fn, 0);
    };
})();

process.title = 'browser';
process.browser = true;
process.env = {};
process.argv = [];

process.binding = function (name) {
    throw new Error('process.binding is not supported');
}

// TODO(shtylman)
process.cwd = function () { return '/' };
process.chdir = function (dir) {
    throw new Error('process.chdir is not supported');
};

},{}],3:[function(require,module,exports){
(function (process){
// Copyright Joyent, Inc. and other Node contributors.
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to permit
// persons to whom the Software is furnished to do so, subject to the
// following conditions:
//
// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN
// NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
// DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
// OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
// USE OR OTHER DEALINGS IN THE SOFTWARE.

// resolves . and .. elements in a path array with directory names there
// must be no slashes, empty elements, or device names (c:\) in the array
// (so also no leading and trailing slashes - it does not distinguish
// relative and absolute paths)
function normalizeArray(parts, allowAboveRoot) {
  // if the path tries to go above the root, `up` ends up > 0
  var up = 0;
  for (var i = parts.length - 1; i >= 0; i--) {
    var last = parts[i];
    if (last === '.') {
      parts.splice(i, 1);
    } else if (last === '..') {
      parts.splice(i, 1);
      up++;
    } else if (up) {
      parts.splice(i, 1);
      up--;
    }
  }

  // if the path is allowed to go above the root, restore leading ..s
  if (allowAboveRoot) {
    for (; up--; up) {
      parts.unshift('..');
    }
  }

  return parts;
}

// Split a filename into [root, dir, basename, ext], unix version
// 'root' is just a slash, or nothing.
var splitPathRe =
    /^(\/?|)([\s\S]*?)((?:\.{1,2}|[^\/]+?|)(\.[^.\/]*|))(?:[\/]*)$/;
var splitPath = function(filename) {
  return splitPathRe.exec(filename).slice(1);
};

// path.resolve([from ...], to)
// posix version
exports.resolve = function() {
  var resolvedPath = '',
      resolvedAbsolute = false;

  for (var i = arguments.length - 1; i >= -1 && !resolvedAbsolute; i--) {
    var path = (i >= 0) ? arguments[i] : process.cwd();

    // Skip empty and invalid entries
    if (typeof path !== 'string') {
      throw new TypeError('Arguments to path.resolve must be strings');
    } else if (!path) {
      continue;
    }

    resolvedPath = path + '/' + resolvedPath;
    resolvedAbsolute = path.charAt(0) === '/';
  }

  // At this point the path should be resolved to a full absolute path, but
  // handle relative paths to be safe (might happen when process.cwd() fails)

  // Normalize the path
  resolvedPath = normalizeArray(filter(resolvedPath.split('/'), function(p) {
    return !!p;
  }), !resolvedAbsolute).join('/');

  return ((resolvedAbsolute ? '/' : '') + resolvedPath) || '.';
};

// path.normalize(path)
// posix version
exports.normalize = function(path) {
  var isAbsolute = exports.isAbsolute(path),
      trailingSlash = substr(path, -1) === '/';

  // Normalize the path
  path = normalizeArray(filter(path.split('/'), function(p) {
    return !!p;
  }), !isAbsolute).join('/');

  if (!path && !isAbsolute) {
    path = '.';
  }
  if (path && trailingSlash) {
    path += '/';
  }

  return (isAbsolute ? '/' : '') + path;
};

// posix version
exports.isAbsolute = function(path) {
  return path.charAt(0) === '/';
};

// posix version
exports.join = function() {
  var paths = Array.prototype.slice.call(arguments, 0);
  return exports.normalize(filter(paths, function(p, index) {
    if (typeof p !== 'string') {
      throw new TypeError('Arguments to path.join must be strings');
    }
    return p;
  }).join('/'));
};


// path.relative(from, to)
// posix version
exports.relative = function(from, to) {
  from = exports.resolve(from).substr(1);
  to = exports.resolve(to).substr(1);

  function trim(arr) {
    var start = 0;
    for (; start < arr.length; start++) {
      if (arr[start] !== '') break;
    }

    var end = arr.length - 1;
    for (; end >= 0; end--) {
      if (arr[end] !== '') break;
    }

    if (start > end) return [];
    return arr.slice(start, end - start + 1);
  }

  var fromParts = trim(from.split('/'));
  var toParts = trim(to.split('/'));

  var length = Math.min(fromParts.length, toParts.length);
  var samePartsLength = length;
  for (var i = 0; i < length; i++) {
    if (fromParts[i] !== toParts[i]) {
      samePartsLength = i;
      break;
    }
  }

  var outputParts = [];
  for (var i = samePartsLength; i < fromParts.length; i++) {
    outputParts.push('..');
  }

  outputParts = outputParts.concat(toParts.slice(samePartsLength));

  return outputParts.join('/');
};

exports.sep = '/';
exports.delimiter = ':';

exports.dirname = function(path) {
  var result = splitPath(path),
      root = result[0],
      dir = result[1];

  if (!root && !dir) {
    // No dirname whatsoever
    return '.';
  }

  if (dir) {
    // It has a dirname, strip trailing slash
    dir = dir.substr(0, dir.length - 1);
  }

  return root + dir;
};


exports.basename = function(path, ext) {
  var f = splitPath(path)[2];
  // TODO: make this comparison case-insensitive on windows?
  if (ext && f.substr(-1 * ext.length) === ext) {
    f = f.substr(0, f.length - ext.length);
  }
  return f;
};


exports.extname = function(path) {
  return splitPath(path)[3];
};

function filter (xs, f) {
    if (xs.filter) return xs.filter(f);
    var res = [];
    for (var i = 0; i < xs.length; i++) {
        if (f(xs[i], i, xs)) res.push(xs[i]);
    }
    return res;
}

// String.prototype.substr - negative index don't work in IE8
var substr = 'ab'.substr(-1) === 'b'
    ? function (str, start, len) { return str.substr(start, len) }
    : function (str, start, len) {
        if (start < 0) start = str.length + start;
        return str.substr(start, len);
    }
;

}).call(this,require("/home/mmoissette/dev/projects/coffeescad/stores/usco-dropbox-store/node_modules/browserify/node_modules/insert-module-globals/node_modules/process/browser.js"))
},{"/home/mmoissette/dev/projects/coffeescad/stores/usco-dropbox-store/node_modules/browserify/node_modules/insert-module-globals/node_modules/process/browser.js":2}],"igeSXk":[function(require,module,exports){
'use strict';
var DropBoxStore, Dropbox, Minilog, Q, detectEnv, logger, path,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

detectEnv = require("composite-detect");

Q = require("q");

path = require("path");

if (detectEnv.isModule) {
  Minilog = require("minilog");
  Minilog.pipe(Minilog.suggest).pipe(Minilog.backends.console.formatClean).pipe(Minilog.backends.console);
  logger = Minilog('dropbox-store');
}

if (detectEnv.isNode) {
  Minilog.pipe(Minilog.suggest).pipe(Minilog.backends.console.formatColor).pipe(Minilog.backends.console);
  Dropbox = require("dropbox");
}

if (detectEnv.isBrowser) {
  Minilog.pipe(Minilog.suggest).pipe(Minilog.backends.console.formatClean).pipe(Minilog.backends.console);
  logger = Minilog('dropbox-store');
  Dropbox = window.Dropbox;
}

DropBoxStore = (function() {
  function DropBoxStore(options) {
    this["delete"] = __bind(this["delete"], this);
    this.move = __bind(this.move, this);
    this.write = __bind(this.write, this);
    this.read = __bind(this.read, this);
    this.mkdir = __bind(this.mkdir, this);
    this.list = __bind(this.list, this);
    this.logout = __bind(this.logout, this);
    this.login = __bind(this.login, this);
    var defaults;
    options = options || {};
    defaults = {
      name: "Dropbox",
      description: "Store to the Dropbox Cloud based storage: requires login",
      rootUri: "/",
      isDataDumpAllowed: false,
      isLoginRequired: true,
      showPaths: false
    };
    this.loggedIn = false;
    if (detectEnv.isNode) {
      this.client = new Dropbox.Client({
        key: "your-key-here",
        secret: "your-secret-here"
      });
    } else {
      this.client = new Dropbox.Client({
        key: "z6yrlcnlyrinlp6",
        sandbox: true
      });
      this.client.authDriver(new Dropbox.AuthDriver.Redirect({
        rememberUser: true,
        useQuery: true
      }));
    }
  }

  DropBoxStore.prototype.login = function() {
    var deferred;
    deferred = Q.defer();
    this.client.authenticate((function(_this) {
      return function(error, client) {
        if (error != null) {
          logger.error("dropbox-store failed to logged in", error);
          return _this.formatError(error, deferred);
        }
        logger.info("dropbox-store logged in");
        _this.loggedIn = true;
        return deferred.resolve(_this);
      };
    })(this));
    return deferred;
  };

  DropBoxStore.prototype.logout = function() {
    var deferred;
    deferred = Q.defer();
    this.client.signOut((function(_this) {
      return function(error) {
        if (error != null) {
          return _this.formatError(error, deferred);
        }
        logger.info("dropbox-store logged out");
        _this.loggedIn = false;
        return deferred.resolve(_this);
      };
    })(this));
    return deferred;
  };


  /*-------------------file/folder manipulation methods---------------- */


  /**
  * list all elements inside the given uri (non recursive)
  * @param {String} uri the folder whose content we want to list
  * @return {Object} a promise, that gets resolved with the content of the uri
   */

  DropBoxStore.prototype.list = function(uri) {
    var deferred;
    deferred = Q.defer();
    this.client.readdir(uri, (function(_this) {
      return function(error, entries, folderStat, entriesStats) {
        if (error) {
          return _this.formatError(error, deferred);
        }
        return deferred.resolve(entries, folderStat, entriesStats);
      };
    })(this));
    return deferred;
  };


  /**
  * create a directory at the given uri
  * @param {String} uri the folder to create
  * @return {Object} a promise, that gets resolved with the current instance, for chaining
   */

  DropBoxStore.prototype.mkdir = function(uri) {
    var deferred;
    deferred = Q.defer();
    this.client.mkdir(uri, (function(_this) {
      return function(error, stats) {
        if (error != null) {
          return _this.formatError(error, deferred);
        }
        return deferred.resolve(_this);
      };
    })(this));
    return deferred;
  };


  /**
  * read the file at the given uri, return its content
  * @param {String} uri absolute uri of the file whose content we want
  * @param {String} encoding the encoding used to read the file
  * @return {Object} a defferred, that gets resolved with the content of file at the given uri
   */

  DropBoxStore.prototype.read = function(uri, encoding) {
    var deferred, options;
    encoding = encoding || 'utf8';
    deferred = Q.defer();
    options = options || {};

    /*
    onProgress= ( event )->
      if (event.lengthComputable)
        percentComplete = (event.loaded/event.total)*100
        logger.debug "percent", percentComplete
        deferred.notify( {"loaded":percentComplete, "total":event.total} )
    @client.onXhr.addListener(onProgress)
    @client.onXhr.removeListener(onProgress)
    var xhrListener = function(dbXhr) {
      dbXhr.xhr.upload.onprogress("progress", function(event) {
    // event.loaded bytes received, event.total bytes must be received
    reportProgress(event.loaded, event.total);
      });
      return true;  // otherwise, the XMLHttpRequest is canceled
    };
    client.onXhr.addListener(xhrListener);
     */
    this.client.readFile(uri, options, (function(_this) {
      return function(error, data) {
        if (error != null) {
          return _this.formatError(error, deferred);
        }
        return deferred.resolve(data);
      };
    })(this));
    return deferred;
  };


  /**
  * write the file at the given uri, with the given data, using given mimetype
  * @param {String} uri absolute uri of the file we want to write (if the intermediate directories do not exist, they get created)
  * @param {String} data the content we want to write to the file
  * @param {String} type the mime-type to use
  * @return {Object} a deferred, that gets resolved with "true" if writing to the file was a success, the error in case of failure
   */

  DropBoxStore.prototype.write = function(uri, content, type, overwrite) {
    var deferred, options;
    type = type || 'utf8';
    overwrite = overwrite || true;
    deferred = Q.defer();
    options = {};
    logger.debug("writing file " + uri + " with content " + content);
    this.client.writeFile(uri, content, options, (function(_this) {
      return function(error, stat) {
        if (error != null) {
          return _this.formatError(error, deferred);
        }
        logger.debug("writen file " + uri + " with content " + content);
        logger.debug("File saved as revision " + stat.versionTag);
        return deferred.resolve(content);
      };
    })(this));
    return deferred;
  };


  /**
  * move/rename the item at first uri to the second uri
  * @param {String} uri absolute uri of the source file or folder
  * @param {String} newuri absolute uri of the destination file or folder
  * @param {Boolean} whether to allow overwriting or not (defaults to false)
  * @return {Object} a promise, that gets resolved with "true" if moving/renaming the file was a success, the error in case of failure
   */

  DropBoxStore.prototype.move = function(uri, newUri, overwrite) {
    var deferred;
    overwrite = overwrite || false;
    deferred = Q.defer();
    this.client.move(uri, newUri, (function(_this) {
      return function(error) {
        if (error != null) {
          return _this.formatError(error, deferred);
        }
        return deferred.resolve(_this);
      };
    })(this));
    return deferred;
  };


  /**
  * delete the file or folder at the given uri
  * @param {String} uri absolute uri of the file we want to write (if the intermediate directories do not exist, they get created)
  * @return {Object} a deferred, that gets resolved with "true" if deleting the file was a success, the error in case of failure
   */

  DropBoxStore.prototype["delete"] = function(uri) {
    var deferred;
    deferred = Q.defer();
    this.client.remove(uri, (function(_this) {
      return function(error, userInfo) {
        if (error) {
          return _this.formatError(error, deferred);
        }
        logger.debug("removed " + uri);
        return deferred.resolve(_this);
      };
    })(this));
    return deferred;
  };


  /*-------------------Helpers---------------- */

  DropBoxStore.prototype.formatError = function(error, deferred) {
    switch (error.status) {
      case 401:
        error = new Error("Dropbox token expired");
        break;
      case 403:
        error = new Error(error.responseText);
        break;
      case 404:
        error = new Error("Failed to find the specified file or folder");
        break;
      case 507:
        error = new Error("Dropbox quota exceeded");
        break;
      case 503:
        error = new Error("Dropbox: too many requests");
        break;
      case 400:
        error = new Error("Dropbox: bad input parameter");
        break;
      case 403:
        error = new Error("Dropbox: bad oauth request");
        break;
      case 405:
        error = new Error("Dropbox: unexpected request method");
        break;
      default:
        error = new Error("Dropbox: uknown error");
    }
    logger.error(error.message);
    return deferred.reject(error);
  };

  DropBoxStore.prototype.authCheck = function() {
    var authOk, getURLParameter, urlAuthOk;
    getURLParameter = function(paramName) {
      var hash, i, params, val;
      hash = window.location.hash;
      params = hash.split("&");
      i = 0;
      while (i < params.length) {
        val = params[i].split("=");
        if (val[0] === paramName) {
          return unescape(val[1]);
        }
        i++;
      }
    };
    urlAuthOk = getURLParameter("#access_token");
    logger.debug("dropboxStore got redirect param " + urlAuthOk);
    authOk = localStorage.getItem("dropbox-store-loggedIn");
    logger.debug("dropboxStore got localstorage Param " + authOk);
    if (urlAuthOk != null) {
      return this.login();
    } else if (authOk != null) {
      return this.login();
    } else {
      return this.loggedIn = false;
    }
  };

  return DropBoxStore;

})();

module.exports = DropBoxStore;


},{"dropbox":1,"path":3,"q":false}],"dropbox-store":[function(require,module,exports){
module.exports=require('igeSXk');
},{}]},{},["igeSXk"])