package pmdb.core;

import pmdb.core.ds.*;
import pmdb.core.StructSchema;
import pmdb.core.Store;
import pmdb.core.Object;
import pmdb.async.Executor;
import pmdb.core.query.*;
import pmdb.storage.*;

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
        if (options.path != null)
            path = options.path;

        executor = new Executor();
        storage = options.storage;
        if (storage == null) {
            storage = Storage.targetDefault();
        }
    }

/* === Methods === */

    public function compact(n: String) {
        stores[n]._compact();
    }

    /**
      obtain a reference to the given table
     **/
    public function table<Row>(name: String):DbStore<Row> {
        return cast stores[name];
    }

    public function addStore<Row>(name:String, store:DbStore<Row>):DbStore<Row> {
        stores[name] = store;
        return store;
    }

    public function dropStore(name: String) {
        var store = table( name );
        return executor.exec(name, function() {
            return storage.unlink(@:privateAccess store.options.filename);
        }).map(function(_) {
            store.reset();
            stores.remove( name );
            return true;
        });
    }

    /**
      create and register a Store<Dynamic> on [this] Database
     **/
    public function createStore(name:String, schema:StructSchema, ?options:StoreOptions):DbStore<Dynamic> {
        if (options == null) {
            options = {};
        }
        var o:StoreOptions = {
            filename: nor(options.filename, Path.join([this.path, '$name.db'])),
            schema: schema,
            inMemoryOnly: path == '<in-memory>',
            primary: schema.primaryKey,
            executor: executor,
            storage: storage
        };
        @:privateAccess schema._init();
        Arch.anon_copy(options, o);

        var store:DbStore<Dynamic> = new DbStore(name, o);
        store = addStore(name, store);
        return store;
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
    public var stores(default, null): Map<String, DbStore<Dynamic>>;
    public var path(default, null): String;

    public var executor(default, null): Executor;
    public var storage(default, null): Null<Storage>;
}

typedef DbOptions = {
    ?path: String,
    ?storage: Storage
};
