package pmdb.core;

import pmdb.core.ds.*;
import pmdb.core.StructSchema;
import pmdb.core.Store;
import pmdb.core.Object;
import pmdb.core.query.*;

import haxe.io.Path;

using pm.Strings;
using pm.Arrays;
using pm.Iterators;
using pm.Functions;

class Database {
    /* Constructor Function */
    public function new(options: DbOptions) {
        stores = new Map();
        path = '<in-memory>';
    }

/* === Methods === */

    public function addStore<Row>(name:String, store:Store<Row>):Store<Row> {
        stores[name] = store;//cast(store, Store<Dynamic>);
        return store;
    }

    /**
      create and register a Store<Dynamic> on [this] Database
     **/
    public function createStore(name:String, schema:StructSchema, ?options:StoreOptions):Store<Dynamic> {
        if (options == null) {
            options = {};
        }
        var o:StoreOptions = {
            filename: nor(options.filename, Path.join([this.path, '$name.db'])),
            schema: schema,
            inMemoryOnly: path == '<in-memory>',
            primary: schema.primaryKey
        };
        @:privateAccess schema._init();

        var store:Store<Dynamic> = new Store( o );

        return addStore(name, store);
    }

    public function dropStore(name: String):Bool {
        return stores.remove( name );
    }

    public function insert(dest:String, row:Doc):Void {
        if (Arch.isArray( row )) {
            stores[dest].insertMany(cast(row, Array<Dynamic>));
        }
        else {
            stores[dest].insertOne( row );
        }
    }

    public function all(d: String) {
        return stores[d].getAllData();
    }

    public function find(d:String, ?check:Criterion<Dynamic>, ?precompile:Bool):FindCursor<Dynamic> {
        return stores[d].find(check, precompile);
    }

/* === Variables === */

    @:noCompletion
    public var stores(default, null): Map<String, Store<Dynamic>>;
    public var path(default, null): String;
}

typedef DbOptions = {
    ?path: String
};
