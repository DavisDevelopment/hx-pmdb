package pmdb.storage;

import pmdb.core.ds.Outcome;
import pmdb.core.Object;
import pmdb.core.Store;
import pmdb.ql.ts.DataType;

import haxe.io.Bytes;

import pmdb.storage.IPersistence;
import pmdb.storage.IStorage;
import pmdb.storage.io.Persistent;
import pmdb.core.Database;
import pmdb.core.StructSchema;
import pm.Path;
import pm.async.*;

using pm.Strings;
using pm.Arrays;
using pm.Iterators;
using pm.Functions;
using pm.Outcome;
using pm.async.Async;

class DatabasePersistence {
    public function new(database) {
        this.owner = database;
        this.storage = owner.storage;
        this.manifest = new Persistent();
        manifest.setFormat(cast Format.json());
        
        manifest.setPath(manifestPath);
        manifest.onOpened = function(info) {
            //
        };
    }

/* === Methods/Functions === */

    public function open(?preloadTables:String):Promise<Bool> {
        return new Promise<Bool>(function(resolve, reject) {
            storage.exists(owner.path).then(
                function(doesExist) {
                    if (doesExist) {
                        manifest.onOpened = function(info) {
                            if (preloadTables.empty()) {
                                resolve(true);
                            }
                            else {
                                //TODO actually process [preloadTables]
                                var storeLoads = info.tables.map(table -> owner.load(table.name));
                                var allLoaded = Promise.all(storeLoads);
                                allLoaded.then(
                                    function(tables) {
                                        // trace(tables);
                                        resolve(true);
                                    },
                                    function(error) {
                                        reject(error);
                                    }
                                );
                            }
                        };
                        manifest.connect(storage);
                        // resolve(true);
                    }
                    else {
                        resolve(false);
                    }
                },
                reject
            );
        });
    }

    public function init():Promise<Bool> {
        return new Promise<Bool>(function(accept, reject) {
            storage.mkdirp(owner.path).then(
                function(status) {
                    if (status) {
                        manifest.connect(storage);
                        accept(true);
                    }
                    else {
                        reject('Poo');
                    }
                },
                reject
            );
        });
    }

    public function sync() {
        manifest.write({
            version: 1,
            tables: owner.stores.iterator().map(function(store) {
                return Tools.jsonTable(store.name, '', store.schema);
            }).array()
        });

        // Callback.defer(manifest.commit);
    }

    public function release() {
        manifest.commit();
        manifest.release();
    }

/* === Internal Methods === */

    private function pathTo(name:String, ?ext:String):Path {
        var res = (dataPath / name);
        if (ext != null) {
            res.ext = ext;
        }
        return res;
    }

/* === Properties === */

    // @:isVar
    public var dataPath(get, never): pm.Path;
    function get_dataPath() {
        return new pm.Path( owner.path );
    }

    public var manifestPath(get, never):pm.Path;
    private inline function get_manifestPath():pm.Path {
        return pathTo('manifest', 'json');
    }

/* === Variables === */

    public var owner(default, null): Database;
    public var storage(default, null):IStorage;
    public var manifest(default, null):Persistent<ManifestData>;

/* === Statics === */

    static inline var MANIFEST = '.manifest';
}

class Tools {
    public static function jsonTable(name:String, pathName:String, structure:StructSchema) {
        return {
            name: name,
            pathName: pathName,
            structure: jsonStructure(structure)
        };
    }
    public static function jsonStructure(schema: StructSchema) {
        return {
            fields: schema.fields.iterator().map(function(field) {
                return {
                    name: field.name,
                    type: field.type.print(),
                    optional: field.optional,
                    unique: field.unique,
                    primary: field.primary,
                    autoIncrement: field.autoIncrement
                };
            }).array(),
            indexes: schema.indexes.iterator().map(function(idx) {
                return {
                    fieldName: idx.name
                };
            }).array(),
            rowClass: schema.type != null && schema.type.proto != null ? Type.getClassName(schema.type.proto) : null
        };
    }
}

typedef ManifestData = {
    var version: Int;
    var tables: Array<TableData>;
};

typedef TableData = {
    var name : String;
    var pathName : String;
    var structure : TableStructureData;
};

typedef TableStructureData = {
    fields: Array<TableFieldData>,
    indexes: Array<TableIndexData>,
    rowClass: Null<String>
};

typedef TableFieldData = {
    var name : String;
    var type : String;
    var optional : Bool;
    var unique : Bool;
    var primary : Bool;
    var autoIncrement : Bool;
};

typedef TableIndexData = {
    var fieldName : String;
};
