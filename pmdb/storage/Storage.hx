package pmdb.storage;

import pmdb.core.ds.Lazy;
import pmdb.core.ds.Outcome;
import pm.async.Promise;

import haxe.io.Bytes;
import haxe.PosInfos;

import pmdb.storage.IStorage;

@:forward
abstract Storage (IStorage) from IStorage to IStorage {
    /**
      @returns a `Storage` object which is bound to the platform-/backend-specific file system APIs
     **/
    public static function fs(specialize:Bool=false):Storage {
        if (specialize) {
            #if (js && hxnodejs)
			    return new AsyncFromCallbackStorageAdapter(new NodeFileSystemStorage());
            #else
                return fs(false);
            #end
        }
        else {
            return inline AsyncStorageAdapter.make(FileSystemStorage.make());
        }
    }

    public static function targetDefault():Storage {
        #if (js && !hxnodejs)
            #error
        #else
            return
            if (useFileSystem)
                Storage.fs()
            else
                throw new pm.Error.NotImplementedError('pmdb.storage.Storage.targetDefault(where @useFileSystem = false)');
        #end
    }

    private static inline final useFileSystem = true;

/* === [Methods and Stuff] === */

    public function mkdirp(path:String):Promise<Bool> {
        try {
            var created = this.mkdirp(path);
            return created.failAfter(1000);
        }
        catch (e: OperationNotImplemented) {
            return IStorageMethods.mkdirp(this, path).failAfter(1000);
        }
    }
}
