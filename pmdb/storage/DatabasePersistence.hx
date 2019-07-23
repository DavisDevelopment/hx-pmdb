package pmdb.storage;

import pmdb.core.ds.Outcome;
import pmdb.core.Object;
import pmdb.core.Store;
import pmdb.ql.ts.DataType;

import haxe.io.Bytes;

import pmdb.storage.IPersistence;
import pm.Path;
import pm.async.*;

using pm.Strings;
using pm.Arrays;
using pm.Functions;
using pm.Outcome;

class DatabasePersistence {
    public function new(database) {
        this.owner = database;
    }

/* === Methods/Functions === */

    public function getManifest() {
        return loadManifest();
    }

    public function loadManifest() {
        return null;
    }

/* === Internal Methods === */

    private function pathTo(name:String, ?ext:String):Path {
        var res = (dataPath + name);
        if (ext != null) {
            res.ext = ext;
        }
        return res;
    }

/* === Properties === */

    public var storage(get, never): Storage;
    inline function get_storage() return owner.storage;

    // @:isVar
    public var dataPath(get, never): pm.Path;
    function get_dataPath() {
        return new pm.Path( owner.path );
    }

/* === Variables === */

    public var owner(default, null): Database;

/* === Statics === */

    static inline var MANIFEST = '.manifest';
}

typedef ManifestData = {
    var tables: Array<TableData>;
};

typedef TableData = {
    var name : String;
    var pathName : String;
    var structure : TableStructureData;
};

typedef TableStructureData = {
    fields: Array<TableFieldData>,
    indexes: Array<TableIndexData>
};

typedef TableFieldData = {
    var name : String;
    var type : String;
    var optional : Bool;
    var unique : Bool;
    var primary : Bool;
    var autoIndex : Bool;
};

typedef TableIndexData = {
    var fieldName : String;
};
