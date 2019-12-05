package pmdb.storage;

import pm.Lazy;
import pm.Outcome;
import pm.async.*;

import haxe.io.Bytes;
import haxe.PosInfos;

typedef TCb<T> = (error:Null<Dynamic>, result:T)->Void;
@:callable
@:forward
abstract Cb<T> (TCb<T>) from TCb<T> to TCb<T> {
    @:from public static function ofCallback<T>(cb: Callback<T>):Cb<T> {
        return (error, value:T) -> {
            if (error != null) 
                cb.invoke(value);
        };
    }
	@:from public static function ofMonad<T>(cb:T->Void):Cb<T> {
		return (error, value:T) -> {
			if (error != null)
				cb(value);
		};
	}
    @:from public static function ofOutcomeMonad<T>(f: Outcome<T, Dynamic> -> Void):Cb<T> {
        return (error, value:T) -> {
            if (nn(error)) return f(Failure(error));
            else return f(Success(value));
        }
    }
}

@:using(pmdb.storage.IStorageMethods)
interface IStorage {
    public function exists(path: String):Promise<Bool>;
    public function size(path: String):Promise<Int>;
    
    public function rename(oldPath:String, newPath:String):Promise<Bool>;
    public function writeFileBinary(path:String, data:Bytes):Promise<Bool>;
    public function readFileBinary(path: String):Promise<Bytes>;
    public function appendFileBinary(path:String, data:Bytes):Promise<Bool>;
    public function writeFile(path:String, data:String):Promise<Bool>;
    public function readFile(path: String):Promise<String>;
    public function appendFile(path:String, data:String):Promise<Bool>;
    public function unlink(path: String):Promise<Bool>;

    /**
      attempts to create a new directory node at `path`
      @param path
      @returns a `Promise<Bool>` which resolves to `true` when the directory was created successfully, and `false` when it was not created because it already exists
      @throws Dynamic underlying SystemError when directory creation fails for any other reason
     **/
    public function mkdir(path:String):Promise<Bool>;
    
    public function mkdirp(path: String):Promise<Bool>;
    public function ensureFileDoesntExist(path: String):Promise<Bool>;
    public function flushToStorage(options: {filename:String, ?isDir:Bool}):Promise<Bool>;
    public function crashSafeWriteFile(path:String, data:Bytes):Promise<Bool>;
    public function ensureDatafileIntegrity(filename: String):Promise<Bool>;
}

/**
  IStorage, but which handles async via callbacks
 **/
interface ICbStorage {
    function exists(path:String, callback:Cb<Bool>):Void;
    function size(path:String, callback:Cb<Int>):Void;
    function rename(oldPath:String, newPath:String, callback:Cb<Bool>):Void;
	function writeFileBinary(path:String, data:Bytes, callback:Cb<Bool>):Void;
	function readFileBinary(path:String, callback:Cb<Bytes>):Void;
	function appendFileBinary(path:String, data:Bytes, callback:Cb<Bool>):Void;
	function writeFile(path:String, data:String, callback:Cb<Bool>):Void;
	function readFile(path:String, callback:Cb<String>):Void;
	function appendFile(path:String, data:String, callback:Cb<Bool>):Void;
	function unlink(path:String, callback:Cb<Bool>):Void;
    function mkdir(path:String, callback:Cb<Bool>):Void;
	function mkdirp(path:String, callback:Cb<Bool>):Void;
	function ensureFileDoesntExist(path:String, callback:Cb<Bool>):Void;
	function flushToStorage(options:{filename:String, ?isDir:Bool}, callback:Cb<Bool>):Void;
	function crashSafeWriteFile(path:String, data:Bytes, callback:Cb<Bool>):Void;
	function ensureDatafileIntegrity(filename:String, callback:Cb<Bool>):Void;
}

interface IStorageSync {
    public function exists(path: String):Bool;
    public function size(path: String):Int;
    public function rename(oldPath:String, newPath:String):Void;
    public function writeFileBinary(path:String, data:Bytes):Void;
    public function readFileBinary(path: String):Bytes;
    public function appendFileBinary(path:String, data:Bytes):Void;
    public function writeFile(path:String, data:String):Void;
    public function readFile(path: String):String;
    public function appendFile(path:String, data:String):Void;
    public function unlink(path: String):Void;
    public function mkdir(path:String):Void;
    public function mkdirp(path: String):Void;
    public function ensureFileDoesntExist(path: String):Bool;
    public function flushToStorage(options: {filename:String, ?isDir:Bool}):Void;
    public function crashSafeWriteFile(path:String, data:Bytes):Void;
    public function ensureDatafileIntegrity(filename: String):Void;
}

class StorageError extends Error {
    public var code(default, null): StorageErrorCode;

    public function new(code, ?message, ?position:PosInfos) {
        super(message, position);

        this.code = code;
    }
}
class OperationNotImplemented extends StorageError {
    public function new(?id:String, ?message, ?position:PosInfos) {
        super(EFallback(id), message, position);
    }
    public static inline function make(?id, ?pos:PosInfos) {
        return new OperationNotImplemented(id, null, pos);
    }
}
typedef OpMissing = OperationNotImplemented;

/**
  see: https://nodejs.org/api/errors.html#errors_class_systemerror
 **/
enum StorageErrorCode {
    /* (Permission Denied) */
    EAccess;
    /* (File exists) */
    EExist;
    /* (Is a Directory) */
    EIsDir;
    EMaxFiles;
    ENoEnt;
    ENotDir;
    ENotEmpty;
    /* (Operation Not Permitted) */
    EPerm;

    /**
	  Operation not implemented by the `Storage` class
      Instructs to the caller that the relevant "fallback" implementation 
      (further identified by `id`, if provided) should be used instead
     **/
    EFallback(?id: String);
}
