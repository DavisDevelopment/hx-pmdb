package pmdb.storage;

import haxe.io.Bytes;
import pmdb.storage.IStorage;
import pm.async.Callback;

#if (js && hxnodejs)

import js.node.Fs;
import js.node.fs.*;
import js.node.buffer.Buffer;
import js.node.buffer.Buffer as NodeBuffer;

using StringTools;
using pm.Strings;
using haxe.io.Path;
using pm.Path;

class NodeFileSystemStorage implements ICbStorage {
    public function exists(path:String, callback:Cb<Bool>) {
        Fs.exists(path, function(does) {
            callback(null, does);
        });
    }

    public function size(path:String, callback:Cb<Int>) {
        Fs.stat(path, (e:js.lib.Error, stats:Stats)->{
            if (nn(e)) return callback(e, null);
            callback(null, Math.round(stats.size));
        });
    }

    public function rename(o, n, cb:Cb<Bool>) {
        Fs.rename(o, n, (error: js.lib.Error) -> {
            if (nn(error)) return cb(error, false);
            cb(null, true);
        });
        // Fs.rename(o, n, function(error) {
        //     if (error != null)
        //         cb(error, false);
        //     else
        //         cb(null, true);
        // });
    }

    public function writeFileBinary(path:String, data:Bytes, callback:Cb<Bool>) {
        // Fs.writeFile(path, NodeBuffer.hxFromBytes(data), toJsCallback(callback, ()->true));
        return Fs.writeFile(path, NodeBuffer.hxFromBytes(data), function(error: js.lib.Error) {
            if (nn( error )) return callback(error, false);
            return callback(null, true);
        });
    }

    public function readFileBinary(path:String, callback:Cb<Bytes>) {
        Fs.readFile(path, function(error:js.lib.Error, data:NodeBuffer) {
            callback(error, if (!nn(error)) data.hxToBytes() else null);
        });
    }

    public function appendFileBinary(path:String, data:Bytes, callback:Cb<Bool>) {
        return callback(new pm.Error('Pewp'), false);
        Fs.appendFile(path, NodeBuffer.hxFromBytes(data), function(error:js.lib.Error) {
            callback(error, !nn(error));
        });
    }

    /**
      poo yai nehni, sha C:
     **/
    public function writeFile(path:String, data:String, callback:Cb<Bool>) {
        // Fs.writeFile(path, data, toJsCallback(callback, ()->true));
		Fs.writeFile(path, data, function(error: js.lib.Error) {
            if (nn(error)) return callback(error, false);
            return callback(null, true);
        });
    }

    public function readFile(path:String, callback:Cb<String>) {
        // return Fs.readFile(path, toJsCallback(callback));
		Fs.readFile((path:FsPath), "", function(error:js.lib.Error, data:String) {
			callback(error, if (!nn(error)) data else null);
		});
    }

    public function appendFile(path:String, data:String, callback:Cb<Bool>) {
        return Fs.appendFile(path, data, function(error:js.lib.Error) {
            callback(error, !nn(error));
        });
    }

    public function unlink(path:String, callback:Cb<Bool>) {
        // return Fs.unlink(path, toJsCallback(callback, ()->true));
        return Fs.unlink(path, (error: js.lib.Error) -> {
            if (nn(error)) {
                trace(error.message);
                callback(error, false);
            }
            else {
                callback(null, true);
            }
        });
    }

    public function mkdir(path:String, callback:Cb<Bool>) {
        // return Fs.mkdir(path, toJsCallback(callback, ()->true));
        return Fs.mkdir(path, (error: js.lib.Error) -> {
            trace('mkdir ${path}');
            if (nn(error)) return callback(null, false);
            callback(null,true);
        });
    }

    public function mkdirp(path:String, callback:Cb<Bool>) {
        // Console.error('abstract method call!');
        throw new pmdb.storage.IStorage.OperationNotImplemented(null, 'mkdirp');
        if (_mkdirp != null) return _mkdirp(path, callback);
        if (_mkdirp == null) {
            try {
				var moduleImpl:Null<String -> ((error:js.lib.Error, made:String) -> Void) -> Void> = js.Lib.require('mkdirp');
                if (moduleImpl != null && Reflect.isFunction(moduleImpl)) {
                    _mkdirp = function(p:String, cb) {
                        moduleImpl(p, (e, created) -> {
                            if (nn(e)) return cb(e, false);
                            cb(null, true);
                        });
                    };
                }
            }
            catch (e: Dynamic) {
                throw new pmdb.storage.IStorage.OperationNotImplemented(null, 'mkdirp');
            }
        }
        if (_mkdirp == null) {
            throw new Error('underlying implementation of Storage.mkdirp not provided');
        }
    }
    private var _mkdirp:Null<String->Cb<Bool>->Void> = null;

    public function ensureFileDoesntExist(path:String, callback:Cb<Bool>) {
        exists(path, function(?error:Dynamic, doesExist:Bool) {
            if (error != null || !doesExist) return callback(error, true);
            unlink(path, callback);
        });
    }

    public function flushToStorage(options:{filename:String, ?isDir:Bool}, callback:Cb<Bool>) {
        /* JS
			* Flush data in OS buffer to storage if corresponding option is set
			* @param {String} options.filename
			* @param {Boolean} options.isDir Optional, defaults to false
			* If options is a string, it is assumed that the flush of the file (not dir) called options was requested
		storage.flushToStorage = function(options, callback) {
			var filename, flags;
			if (typeof options == = 'string') {
				filename = options;
				flags = 'r+';
			} else {
				filename = options.filename;
				flags = options.isDir ? 'r' : 'r+';
			}

			// Windows can't fsync (FlushFileBuffers) directories. We can live with this as it cannot cause 100% dataloss
			// except in the very rare event of the first time database is loaded and a crash happens
			if (flags == = 'r' && (process.platform == = 'win32' || process.platform == = 'win64')) {
				return callback(null);
			}

			fs.open(filename, flags, function(err, fd) {
				if (err) {
					return callback(err);
				}
				fs.fsync(fd, function(errFS) {
					fs.close(fd, function(errC) {
						if (errFS || errC) {
							var e = new Error('Failed to flush to storage');
							e.errorOnFsync = errFS;
							e.errorOnClose = errC;
							return callback(e);
						} else {
							return callback(null);
						}
					});
				});
			});
		};
        */
        return callback(new pm.Error.NotImplementedError('flushToStorage("${options.filename}")'), false);
    }

    public inline function crashSafeWriteFile(path:String, data:Bytes, callback:Cb<Bool>) {
        //Console.debug('<b>TODO:</> crashSafeWriteFile');
        return writeFileBinary(path, data, callback);
    }

    public inline function ensureDatafileIntegrity(path:String, callback:Cb<Bool>) {
        //Console.debug('<b>TODO: </>ensureDatafileIntegrity');
        return callback(null, true);
    }

    public function new() {
        //aw yeah
    }

/* === [Internal Utility Methods] === */

	static inline function toCallback<T>(callback:Cb<T>):Callback<T> {
		return function(result:T) {
			return callback(null, result);
		}
	}

	static inline function toJsCallback<T>(callback:Cb<T>, success:Void->T, ?mapError:js.lib.Error->Dynamic, ?pos:haxe.PosInfos):js.lib.Error->Void {
		return function(error) {
			trace('wrapped ${pos.className}.${pos.methodName} has been invoked');
			if (error != null) {
				var err:Dynamic = error;
				if (mapError != null)
					err = mapError(error);

				trace('Failure: $err');
				return callback(err, null);
			} else {
				var result = success();
				trace('Success: $result');
				return callback(null, success());
			}
		};
	}

	static inline function convert<T>(callback:Cb<T>) {
		return callback;
	}
}

#end