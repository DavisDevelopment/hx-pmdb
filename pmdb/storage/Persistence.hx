package pmdb.storage;

import pmdb.core.ds.Outcome;
import pmdb.core.Object;
import pmdb.core.Store;
import pmdb.ql.ts.DataType;

import haxe.io.Bytes;

import pmdb.storage.IPersistence;
import pm.async.*;

import pm.Assert.assert;

using StringTools;
using pm.Strings;
using pm.Arrays;
using pm.Iterators;

class Persistence<Item> {
    /* Constructor Function */
    public function new(options) {
        this.options = options;
        this.filename = options.filename;
        this.storage = (options.storage != null ? options.storage : Storage.targetDefault());
        this.format = (options.format != null ? options.format : Format.json());
    }

/* === Methods === */

    public function ensureDirectoryExists(path: String):Promise<String> {
        return storage.mkdirp( path ).map(function(status) {
            return path;
        });
    }

    /**
      encode the DataStore
     **/
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

    /**
      parse (and compact) the raw serialized store format into a dynamic representation of the store's contents
     **/
    public function decodeRawStoreData(data: Bytes):RawStoreData<Item> {
        var textData:String = data.toString();
        var data:Array<String> = data.toString().split('\n');
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
    public function loadRawStoreData(?options: {?filename:String}):Promise<Null<RawStoreData<Item>>> {
        if (options == null) options = {};
        var path:String = nor(options.filename, filename);
        try {
            return dataFileExists(path).flatMap(function(status: Bool):Promise<Null<RawStoreData<Item>>> {
                if ( status ) {
                    return storage.readFileBinary( path ).map( decodeRawStoreData );
                }
                else {
                    return Promise.resolve( null );
                }
            });
        }
        catch (error: Dynamic) {
            return Promise.reject( error );
        }
    }

    /**
      load the datafile onto the given Store instance
     **/
/* === <//> === */
    /**
      [TODO] 
       * find why the routine is being invoked twice, and correct this; 
       * it's probably causing a call to `store.reset()` to be deferred 
       * onto the frame after the raw data has been copied over, erasing it
     **/
    public function loadDataStore(store:Store<Item>, ?options:{?filename:String}):Promise<Store<Item>> {
        if (loadedDataStorePromise != null)
            return loadedDataStorePromise;
        
        if (loadDataStoreCallCount != 0) {
            throw new pm.Error.InvalidOperation('.loadDataStore(...)');
        }
        loadDataStoreCallCount++;
        
        if (options == null) 
            options = {};
        
        return loadedDataStorePromise = (loadRawStoreData({
            filename: options.filename
        })
        .map(function(raw: Null<RawStoreData<Item>>) {
            if (raw == null) {
                throw new pm.Error('Should not be null');
                return store;
            }
            else {
                //(?)TODO add internal methods for stash/pop management of store state
                // TODO stop using the store's datafile for schema-related computations
                var allocatedSize = store.size();
                store.reset();
                @:privateAccess store._init_indices_();

                if (raw.docs != null) {
                    store.insertMany(raw.docs);
                }
                trace('Inserted ${raw.docs.length} rows; Store has ${store.size()} rows in total');
                return store;
            }
        }));
    }

    private var loadDataStoreCallCount:Int = 0;
    private var loadedDataStorePromise:Null<Promise<Store<Item>>> = null;

    /**
      persist the given Store instance to the datafile
     **/
    public function persistCachedDataStore(store: Store<Item>):Promise<Store<Item>> {
        try {
            final data = encodeDataStore( store );
            return storage.crashSafeWriteFile(filename, data).map(x -> store);
        }
        catch (error: Dynamic) {
            trace('$error');
            return Promise.reject( error );
        }
    }

    /**
      add new states
     **/
    public function persistNewState(docs: Array<Object<Dynamic>>):Promise<Bool> {
        var b = new StringBuf();
        docs.iter(function(item) {
            b.add(serialize( item ));
            b.addChar('\n'.code);
        });

        var data = Bytes.ofString(b.toString());
        var promise = storage.appendFileBinary(filename, data);
        return promise;
    }

    /**
      check whether the data-file exists
     **/
    public inline function dataFileExists(?argFilename: String):Promise<Bool> {
        var path:String = getPath(argFilename);
        assert(!path.empty());
        trace('filename="$filename"');
        return storage.exists(path);
    }

    inline function getPath(?overrideFilename: String):String {
        return pm.Helpers.nor(overrideFilename.nullEmpty(), this.filename);
    }

    private function serialize(item: Dynamic):String {
        var enc = format.encode( item );
        if (options.afterSerialization != null)
            enc = options.afterSerialization( enc );
        return enc;
    }

    private function deserialize(data: String):Dynamic {
        if (options.beforeDeserialization != null)
            data = options.beforeDeserialization( data );
        var parsed = format.decode( data );
        return parsed;
    }

/* === Fields === */

    public var options(default, null): PersistenceOptions;

    public var filename(default, null): String;
    public var storage(default, null): Storage;
    public var format(default, null): Format<Dynamic, String>;

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
