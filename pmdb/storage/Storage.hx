package pmdb.storage;

import pmdb.core.ds.Lazy;
import pmdb.core.ds.Outcome;

import haxe.io.Bytes;
import haxe.PosInfos;

import pmdb.storage.IStorage;

@:forward
abstract Storage (IStorage) from IStorage to IStorage {
    public static inline function fs():Storage {
        return inline AsyncStorageAdapter.make(FileSystemStorage.make());
    }

    public static inline function targetDefault():Storage {
        #if (sys || hxnodejs)
            return fs();
        #else
            #error
        #end
    }
}
