package pmdb.core;

import pmdb.core.ds.*;
import pmdb.core.StructSchema;
import pmdb.core.Store;
import pmdb.core.Object;
import pmdb.async.Executor;
import pmdb.core.query.*;
import pmdb.storage.*;

import pm.async.*;

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

        loadedStores = new Map();
        connections = new Map();
    }

/* === Methods === */

    public function compact(n: String) {
        stores[n]._compact();
        return loadedStores[n];
    }

    public function load(name: String):Promise<DbStore<Dynamic>> {
        /*
        if (loadedStores.exists( name )) {
            return loadedStores[name];
        }
        else {
            return (loadedStores[name] = cast table(name)._load());
        }
        */
        stores[name]._load();
        return loadedStores[name];
    }

    

    /**
      obtain a reference to the given table
     **/
    public function table<Row>(name: String):DbStore<Row> {
        return cast stores[name];
    }

    public function addStore<Row>(name:String, store:DbStore<Row>):DbStore<Row> {
        stores[name] = store;
        store._load();
        return store;
    }

    /**
      deallocate, delete and untrack the named store
    **/
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
    public function createStore(name:String, schema:StructSchema, ?options:StoreOptions) {
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

        var store:DbStore<Dynamic> = new DbStore(name, this, o);
        store = addStore(name, store);
        //return store;
    }

    /**
      insert a new Doc into the given table
    **/
    public function insert(dest:String, row:Doc):Void {
        if (Arch.isArray( row )) {
            stores[dest].insertMany(cast(row, Array<Dynamic>));
        }
        else {
            stores[dest].insertOne( row );
        }
    }

    /**
      get all rows from the given table
    **/
    public function all<Row>(d: String):Array<Row> {
        return cast stores[d].getAllData();
    }

    /**
      perform a 'find', or a 'select' query on [this] Database
    **/
    public function find(d:String, ?check:Criterion<Dynamic>, ?precompile:Bool):FindCursor<Dynamic> {
        return stores[d].find(check, precompile);
    }

    /**
      perform a single-index lookup
    **/
    public function get<Row>(table:String, a:Dynamic, ?b:Dynamic):Null<Row> {
        return stores[table].get(a, b);
    }

    public function open<Item>(table: String):StoreConnection<Item> {
        if (!loadedStores.exists( table )) {
            //
            throw 'iEatAss';
        }
        if (!connections.exists( table )) {
            connections[table] = cast new StoreConnection<Item>(this, table);
        }
        //return cast (connections[table] = cast new StoreConnection<Item>(this, table));
        return cast connections[table];
    }

/* === Variables === */

    @:noCompletion
    public var stores(default, null): Map<String, DbStore<Dynamic>>;
    public var path(default, null): String;

    public var executor(default, null): Executor;
    public var storage(default, null): Null<Storage>;

    private var loadedStores: Map<String, Promise<DbStore<Dynamic>>>;
    private var connections: Map<String, StoreConnection<Dynamic>>;
}

typedef DbOptions = {
    ?path: String,
    ?storage: Storage
};

@:access(pmdb.core.Database)
class StoreConnection<Item> {
    public var db: Database;
    public var storeName: String;

    public function new(db, name) {
        this.db = db;
        this.storeName = name;
    }

    public function all() {return fmr(store -> store.getAllData());}
    public function get(a:Dynamic, ?b:Dynamic):Promise<Null<Item>> {
        return fmr.fn(_.get(a, b));
    }
    public function find(q:Criterion<Item>, ?precompile:Bool):Promise<FindCursor<Item>> return fmr.fn(_.find(q, precompile));

    public function close():Promise<Bool> {
        return Promise.resolve(true);
    }

    private inline function prom():Promise<DbStore<Item>> {
        return cast db.loadedStores[storeName];
    }

    private inline function fm<T>(f: DbStore<Item> -> Promise<T>):Promise<T> {
        return prom().flatMap( f );
    }

    private inline function fmr<T>(f: DbStore<Item> -> T):Promise<T> {
        return fm(x -> Promise.resolve(f(x)));
    }
}

private typedef IStoreSync<Item> = {
    function all():Array<Item>;
    function get(a:Dynamic, ?b:Dynamic):Null<Item>;
    function find(q:Criterion<Item>, ?precompile:Bool):FindCursor<Item>;
    function findAll(q: Criterion<Item>, ?precompile:Bool):Array<Item>;
    function findOne(q: Criterion<Item>, ?precompile:Bool):Null<Item>;
    function remove(q:Criterion<Item>, ?multiple:Bool):Array<Item>;
    function update(what:Mutation<Item>, ?where:Criterion<Item>, ?options:{?precompile:Bool, ?multiple:Bool, ?insert:Bool}):UpdateHandle<Item>;
    function count(query:Criterion<Item>):Int;
    function insert(doc: OneOrMany<Item>):Void;
    function size():Int;
};
private typedef IStoreConn<Item> = {
    function all():Promise<Array<Item>>;
    function get(a:Dynamic, ?b:Dynamic):Promise<Null<Item>>;
    //TODO create better type for Promise<FindCursor<Item>>
    function find(q:Criterion<Item>, ?precompile:Bool):Promise<FindCursor<Item>>;
    function findAll(q: Criterion<Item>, ?precompile:Bool):Promise<Array<Item>>;
    function findOne(q: Criterion<Item>, ?precompile:Bool):Promise<Null<Item>>;
    function remove(q:Criterion<Item>, ?multiple:Bool):Promise<Array<Item>>;
    function update(what:Mutation<Item>, ?where:Criterion<Item>, ?options:{?precompile:Bool, ?multiple:Bool, ?insert:Bool}):Promise<UpdateHandle<Item>>;
    function count(query:Criterion<Item>):Promise<Int>;
    function insert(doc: OneOrMany<Item>):Promise<Void>;
    function size():Promise<Int>;
}