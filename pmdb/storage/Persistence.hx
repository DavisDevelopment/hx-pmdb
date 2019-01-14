package pmdb.storage;

import pmdb.core.ds.Outcome;
import pmdb.core.Object;
import pmdb.core.Store;
import pmdb.ql.ts.DataType;

import haxe.io.Bytes;

import pmdb.storage.IPersistence;

using Lambda;
using tannus.ds.ArrayTools;
using StringTools;
using tannus.ds.StringUtils;
using tannus.FunctionTools;

class Persistence<Item> {
    /* Constructor Function */
    public function new(options) {
        this.options = options;
        this.filename = options.filename;
        this.storage = (options.storage != null ? options.storage : Storage.targetDefault());
    }

/* === Methods === */

    public function ensureDirectoryExists(path: String):Outcome<String, Dynamic> {
        try {
            storage.mkdirp( path );
            return Success( path );
        }
        catch (error: Dynamic) {
            return Failure( error );
        }
    }

    public function encodeDataStore(store: Store<Item>):Bytes {
        var b = new StringBuf();

        store.getAllData().iter(function(doc: Item) {
            b.add(serialize( doc ));
            b.addChar('\n'.code);
        });

        for (index in store.indexes) {
            b.add(serialize({
                '$$indexCreated': {
                    fieldName: index.fieldName,
                    fieldType: haxe.Serializer.run( index.fieldType ),
                    unique: index.unique,
                    sparse: index.sparse
                }
            }));
            b.addChar('\n'.code);
        }

        return Bytes.ofString(b.toString());
    }

    public function decodeRawStoreData(data: Bytes):RawStoreData<Item> {
        //#if neko
        //trace(data.toString());
        //#end
        var data:Array<String> = data.toString().split('\n');
        #if neko
        trace(data[0]);
        #end
        var dataById:Map<String, Item> = new Map();
        var tdata = new Array();
        var indexes = new Map();
        var corruptItems = -1;

        for (i in 0...data.length) {
            var doc: Object<Dynamic>;

            try {
                doc = deserialize(data[i]);
                //#if neko trace( doc ); #end

                if (doc.exists( '_id' )) {
                    if (doc["$$deleted"] == true) {
                        dataById.remove(Std.string( doc._id ));
                    }
                    else {
                        dataById[Std.string( doc._id )] = cast doc;
                    }
                }
                else if (doc.exists("$$indexCreated") && doc["$$indexCreated"].fieldName != null) {
                    var ic = doc["$$indexCreated"];
                    indexes[Std.string(ic.fieldName)] = {
                        fieldName: Std.string( ic.fieldName ),
                        fieldType: ic.fieldType == null ? null : haxe.Unserializer.run('' + ic.fieldType),
                        unique: ic.unique == true,
                        sparse: ic.sparse == true
                    };
                }
                else if (doc.exists("$$indexRemoved") && (doc["$$indexRemoved"] is String)) {
                    indexes.remove('' + doc["$$indexRemoved"]);
                }
            }
            catch (error: Dynamic) {
                #if debug
                    trace('$error');
                #end

                corruptItems++;
            }
        }

        if (data.length > 0 && corruptItems / data.length > corruptAlertThreshold) {
            throw new Error('More than ${Math.floor(100 * corruptAlertThreshold)}% of the data file is corrupt, the wrong beforeDeserialization hook may be used. Cautiously refusing to start PmDB to prevent dataloss');
        }

        for (id in dataById.keys()) {
            tdata.push(dataById[id]);
        }

        return {
            docs: tdata,
            indexes: [for (idx in indexes) idx]
        };
    }

    /**
      load and parse the raw store-data from the datafile
     **/
    public function loadRawStoreData():Outcome<Null<RawStoreData<Item>>, Dynamic> {
        try {
            if (dataFileExists()) {
                var data = storage.readFileBinary( filename );
                return Success(decodeRawStoreData( data ));
            }
            else {
                return Success(null);
            }
        }
        catch (error: Dynamic) {
            return Failure( error );
        }
    }

    /**
      load the datafile onto the given Store instance
     **/
    public function loadDataStore(store: Store<Item>):Void {
        store.reset();

        switch (loadRawStoreData()) {
            case Success(null):
                return ;

            case Success({docs:items, indexes:indexes}):
                for (index in indexes) {
                    store.ensureIndex({
                        name: index.fieldName,
                        type: index.fieldType,
                        unique: index.unique,
                        sparse: index.sparse
                    });
                }
                store.insertMany( items );

            case Failure( error ):
                throw error;
        }
    }

    /**
      persist the given Store instance to the datafile
     **/
    public function persistCachedDataStore(store: Store<Item>):Outcome<Bytes, Dynamic> {
        try {
            final data = encodeDataStore( store );
            storage.crashSafeWriteFile(filename, data);
            return Success( data );
        }
        catch (error: Dynamic) {
            return Failure( error );
        }
    }

    public function persistNewState(docs: Array<Object<Dynamic>>):Void {
        var b = new StringBuf();
        docs.iter(function(item) {
            b.add(serialize( item ));
            b.addChar('\n'.code);
        });
        var data = Bytes.ofString(b.toString());
        storage.appendFileBinary(filename, data);
    }

    public inline function dataFileExists():Bool {
        return inline storage.exists( filename );
    }

    private function serialize(item: Dynamic):String {
        return haxe.Json.stringify( item );
    }

    private function deserialize(data: String):Dynamic {
        var parsed = haxe.Json.parse( data );
        return parsed;
    }

/* === Fields === */

    public var options(default, null): PersistenceOptions;

    public var filename(default, null): String;
    public var storage(default, null): Storage;

    public var corruptAlertThreshold : Float = 0.1;
}

typedef RawStoreData<Item> = {
    docs: Array<Item>,
    indexes: Array<{
        fieldName: String,
        ?fieldType: DataType,
        unique: Bool,
        sparse: Bool
    }>
};
