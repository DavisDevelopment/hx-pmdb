package pmdb.storage;

import js.node.buffer.Buffer;
import haxe.io.Bytes;
import pmdb.storage.IStorage;

#if js

import js.node.Fs;
import js.node.fs.*;
import js.node.buffer.Buffer as NodeBuffer;

class NodeCbStorage implements ICbStorage {
    public function exists(path:String, callback:Callback<Bool>) {
        Fs.exists(path, callback);
    }
    public function size(path:String, callback:Cb<Int>) {
        Fs.stat(path, function(err, stats) {
            if (err != null)
                callback(err, null);
            else if (stats != null) {
                Console.examine(stats);
                callback(null, Math.round(stats.size));
            }
        });
    }
    static inline function toJsCallback<T>(callback:Cb<T>, success:Void->T, ?mapError:js.lib.Error->Dynamic):js.lib.Error->Void {
        return function(error) {
            if (error != null) {
                var err:Dynamic = error;
                if (mapError != null)
                    err = mapError(error);
                callback(err, null);
            }
            else {
                callback(null, success());
            }
        };
    }
    public inline function rename(o, n, cb:Cb<Bool>) {
        Fs.rename(o, n, function(error) {
            if (error != null)
                cb(error, false);
            else
                cb(null, true);
        });
    }

    public inline function writeFileBinary(path:String, data:Bytes, callback:Cb<Bool>) {
        Fs.writeFile(path, NodeBuffer.hxFromBytes(data), toJsCallback(callback));
    }

    public inline function readFileBinary(path:String, callback:Cb<Bytes>) {
        Fs.readFile(
            path,
            {
                encoding: null,
                flag: null
            },
            function(error, buffer:NodeBuffer) {
                if (error != null) {
                    callback(error, null);
                }
                else {
                    callback(null, buffer.hxToBytes());
                }
            }
        );
    }

    public inline function appendFileBinary(path:String, data:Bytes, callback:Cb<Bool>) {
        Fs.appendFile(path, NodeBuffer.hxFromBytes(data), toJsCallback(callback, ()->true));
    }
}

#end