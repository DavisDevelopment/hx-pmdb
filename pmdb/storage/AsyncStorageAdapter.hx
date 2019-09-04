package pmdb.storage;

import pmdb.storage.IStorage;

import haxe.io.*;

import pm.async.*;
import pm.Outcome;

class AsyncStorageAdapter implements IStorage {
    public var storage(default, null): IStorageSync;
    
    function new(s) {
        storage = s;
    }

    public static function make(s: IStorageSync) {
        return new AsyncStorageAdapter( s );
    }

    public function exists(path: String):Promise<Bool> {
        return Promise.resolve(storage.exists( path ));
    }

    public function rename(n1:String, n2:String):Promise<Bool> {
        return doo(function() {
            storage.rename(n1, n2);
        });
    }

    public function writeFileBinary(path:String, data:Bytes):Promise<Bool> {
        return doo(function() {
            storage.writeFileBinary(path, data);
        });
    }

    public function readFileBinary(path: String):Promise<Bytes> {
        return prom(storage.readFileBinary.bind(path));
    }

    public function appendFileBinary(path:String, data:Bytes):Promise<Bool> {
        return doo(function() {
            storage.appendFileBinary(path, data);
        });
    }

     public function writeFile(path:String, data:String):Promise<Bool> {
        return doo(function() {
            storage.writeFile(path, data);
        });
    }

    public function readFile(path: String):Promise<String> {
        return prom(storage.readFile.bind(path));
    }

    public function appendFile(path:String, data:String):Promise<Bool> {
        return doo(function() {
            storage.appendFile(path, data);
        });
    }

    public function unlink(path:String):Promise<Bool> {
        return doo(() -> storage.unlink(path));
    }

    public function mkdirp(path: String):Promise<Bool> {
        return doo(storage.mkdirp.bind(path));
    }

    public function flushToStorage(options: {filename:String, ?isDir:Bool}):Promise<Bool> {
        return doo(storage.flushToStorage.bind(options));
    }

    public function ensureDatafileIntegrity(path: String):Promise<Bool> {
        return doo(storage.ensureDatafileIntegrity.bind(path));
    }

    public function crashSafeWriteFile(path:String, data:Bytes):Promise<Bool> {
        return doo(storage.crashSafeWriteFile.bind(path, data));
    }

    public function ensureFileDoesntExist(path: String):Promise<Bool> {
        return doo(storage.ensureFileDoesntExist.bind( path ));
    }

    static function doo(fn: Void->Void):Promise<Bool> {
        return new Promise(function(yes, no) {
            try {
                fn();
                yes( true );
            }
            catch (e: Dynamic) {
                no( e );
            }
        });
    }

    static function prom<T>(fn: Void->T):Promise<T> {
        return new Promise(function(yes, no) {
            try {
                yes(fn());
            }
            catch (err: Dynamic) {
                no( err );
            }
        });
    }
}
