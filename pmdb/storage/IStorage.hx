package pmdb.storage;

import pm.Lazy;
import pm.Outcome;
import pm.async.*;

import haxe.io.Bytes;
import haxe.PosInfos;

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
    public function mkdirp(path: String):Promise<Bool>;
    public function ensureFileDoesntExist(path: String):Promise<Bool>;
    public function flushToStorage(options: {filename:String, ?isDir:Bool}):Promise<Bool>;
    public function crashSafeWriteFile(path:String, data:Bytes):Promise<Bool>;
    public function ensureDatafileIntegrity(filename: String):Promise<Bool>;
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
}
