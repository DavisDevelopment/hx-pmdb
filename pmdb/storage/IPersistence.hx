package pmdb.storage;

import pmdb.core.ds.Outcome;
import pmdb.core.Store;
import pmdb.storage.IStorage;

import pm.async.*;

import haxe.io.Bytes;

interface IPersistence <Options: PersistenceOptions, Item> {
/* === Fields === */

    public var options(default, null): Options;

    public var filename(default, null): String;

    public var storage(default, null): Storage;

/* === Methods === */

    public function ensureDirectoryExists(path: String):Promise<String>;
    public function encodeDataStore(store: Store<Item>):Promise<Bytes>;
    public function persistCachedDataStore(store: Store<Item>):Promise<Bytes>;
    public function compactDataStore(store: Store<Item>):Promise<Bool>;
    public function persistNewState(newDocs: Array<Item>):Promise<String>;
    public function treatRawData(raw: Bytes):Promise<{data:Array<Item>, indexes:Array<String>}>;
    public function loadDataStore():Promise<pmdb.core.Store<Item>>;
    public function close():Promise<Bool>;
}

interface IPersistenceSync <Options: PersistenceOptions, Item> {
/* === Fields === */

    public var options(default, null): Options;

    public var filename(default, null): String;
    //public var store(default, null): Store<Item>;
    public var storage(default, null): Storage;

/* === Methods === */

    public function ensureDirectoryExists(path: String):Outcome<String, Dynamic>;
    public function encodeDataStore(store: Store<Item>):Bytes;
    public function persistCachedDataStore(store: Store<Item>):Outcome<Bytes, Dynamic>;
    public function compactDataStore(store: Store<Item>):Void;
    public function persistNewState(newDocs: Array<Item>):Outcome<String, Dynamic>;
    public function treatRawData(raw: Bytes):Outcome<{data:Array<Item>, indexes:Array<String>}, Dynamic>;
    public function loadDataStore():Outcome<pmdb.core.Store<Item>, Dynamic>;
    public function close():Void;
}

typedef PersistenceOptions = {
    var filename : String;
    var ?afterSerialization : String -> String;
    var ?beforeDeserialization : String -> String;
    var ?storage : Storage;
}
