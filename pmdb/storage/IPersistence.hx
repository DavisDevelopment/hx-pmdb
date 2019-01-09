package pmdb.storage;

import pmdb.core.ds.Outcome;
import pmdb.core.Store;

import haxe.io.Bytes;

interface IPersistence <Options:PersistenceOptions, Item> {
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
