package pmdb.storage;

// package pmdb.storage;

import pmdb.storage.IStorage;
import haxe.io.*;
import pm.async.*;
import pm.async.
import pm.Outcome;

class AsyncFromCallbackStorageAdapter implements IStorage {
    public var storage: ICbStorage;
    public function new(s) {
        this.storage = s;
    }
    public function exists(path:String):Promise<Bool> return Promise.async(function(done) {
        storage.exists;
    });
}