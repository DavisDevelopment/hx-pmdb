package pmdb.core;

import pm.async.Deferred.AsyncDeferred;
import haxe.ds.StringMap;
import pmdb.core.ds.*;
import pmdb.core.FrozenStructSchema;
import pmdb.core.StructSchema;
import pmdb.core.Store;
import pmdb.core.Object;
import pmdb.async.Executor;
import pmdb.core.query.*;
import pmdb.storage.*;
import pmdb.storage.DatabasePersistence;

import pm.async.*;

import haxe.io.Path;
import haxe.ds.Option;
import haxe.extern.EitherType as Or;

using pm.Strings;
using pm.Arrays;
using pm.Iterators;
using pm.Functions;
using pm.Options;

/**
  class which represents a collection of tables (`Store` instances) 
 **/
@:expose
class Database extends Emitter<String, Dynamic> {
    /* Constructor Function */
    public function new(options: DbOptions & {?autoOpenTables:String}) {
        super();
        _signals = new StringMap();
        isAsync = true;
        stores = new Map();
        declaredTables = new Map();
        path = '<in-memory>';
        if (options.path != null) {
            path = options.path;
        }

        executor = new Executor();
        storage = options.storage;
        if (storage == null) {
            storage = Storage.targetDefault();
        }

        persistence = new DatabasePersistence( this );

        loadedStores = new Map();
        loadingStores = new Map();
        connections = new Map();

        addEvent('opened');
        addEvent('initialized');
        addEvent('ready');
        addEvent('closed');

        defer(function() {
            _openSelf(options.autoOpenTables);
        });

        once('opened', function(_) {
            defer(() -> emit('ready', null));
        });
        once('initialized', function(_) {
            emit('ready', null);
        });
        once('ready', function(_) {
            this._isReady = true;
            persistence.manifest.connect(storage);
        });
    }

/* === Methods === */

    public function whenReady(f: Void->Void) {
        if (_isReady) {
            defer(f);
        }
        else {
            once('ready', (_) -> f());
        }
    }

    public function _openSelf(?tables:String) {
        persistence.open(tables).then(
            function(status) {
                if ( status ) {
                    trace('opened');
                    emit('opened', null);
                }
                else {
                    trace('Database.persistence.init()');
                    persistence.init().then(
                        function(status) {
                            if (status) {
                                emit('initialized', null);
                            }
                            else {
                                throw 'Initialization of Database failed';
                            }
                        },
                        err -> {
                            throw err;
                        }
                    );
                }
            },
            function(error) {
                throw error;
            }
        );
    }

    /**
      synchronizes `this` Database
      @see `DatabasePersistence.sync`
     **/
    public function sync() {
        persistence.sync();
    }

    /**
      closes `this` Database, and ceases all communication with it
      [TODO] use lockFile to track whether a Database folder is being managed by an active process already
     **/
    public function close() {
        persistence.release();
    }

    /**
      compact the table denoted by @param name
      @returns `DbStore<Dynamic>`
     **/
    public function compact(name: String) {
        stores[name]._compact();
        return loadedStores[name];
    }

    static function failWhenNone<T>(promise: Promise<Option<T>>):Promise<T> {
        return (promise.outcomeMap(function(outcome: pm.Outcome<Option<T>, Dynamic>) {
            return switch outcome {
                case Failure(err):
                    Failure(err);
                case Success(Some(value)):
                    Success(value);

                case Success(None):
                    Failure(None);
            }
        }) : Promise<T>);
    }

    /**
      load the table denoted by @param name
     **/
    public function load(name: String):Promise<DbStore<Dynamic>> {
        getTable(name);

        if (loadedStores.exists(name)) {
            return loadedStores[name];
        }
        else {
            throw 'WTF?';
        }
    }

    function schemaFromData(data: TableStructureData):StructSchema {
        var data = {structure: data};
        var init:pmdb.core.FrozenStructSchema.FrozenStructSchemaInit = {
            fields: new Array(),
            indexes: new Array(),
            options: {}
        };
        init.fields.resize(data.structure.fields.length);
        init.indexes.resize(data.structure.indexes.length);

        for (i in 0...data.structure.fields.length) {
            var f = data.structure.fields[i];
            init.fields[i] = {
                name: f.name,
                type: ValType.ofString(f.type),
                flags: {
                    optional: f.optional,
                    unique: f.unique,
                    autoIncrement: f.autoIncrement,
                    primary: f.primary
                }
            };
        }

        for (i in 0...data.structure.indexes.length) {
            var idx = data.structure.indexes[i];
            init.indexes[i] = {
                name: idx.fieldName
            };
        }

        var rowClass:Null<Class<Dynamic>> = null;
        if (data.structure.rowClass != null)
            rowClass = Type.resolveClass(data.structure.rowClass);
        if (rowClass == null)
            throw new pm.Error('Class<${data.structure.rowClass}> not found!');

        var schema:StructSchema = new FrozenStructSchema(init.fields, init.indexes, init.options).thaw(rowClass);

        return schema;
    }

    /**
      build a Store<?> object from the given TableData
     **/
    function tableFromData(data: TableData):DbStore<Dynamic> {
        var init:pmdb.core.FrozenStructSchema.FrozenStructSchemaInit = {
            fields: new Array(),
            indexes: new Array(),
            options: {}
        };
        init.fields.resize(data.structure.fields.length);
        init.indexes.resize(data.structure.indexes.length);

        for (i in 0...data.structure.fields.length) {
            var f = data.structure.fields[i];
            init.fields[i] = {
                name: f.name,
                type: ValType.ofString(f.type),
                flags: {
                    optional: f.optional,
                    unique: f.unique,
                    autoIncrement: f.autoIncrement,
                    primary: f.primary
                }
            };
        }

        for (i in 0...data.structure.indexes.length) {
            var idx = data.structure.indexes[i];
            init.indexes[i] = {
                name: idx.fieldName
            };
        }

        var schema:StructSchema = new FrozenStructSchema(init.fields, init.indexes, init.options).thaw();
        var o:StoreOptions = {
            filename: Path.join([this.path, '${data.name}.db']),
            schema: schema,
            inMemoryOnly: false,
            primary: schema.primaryKey,
            executor: executor,
            storage: storage
        };
        var store:DbStore<Dynamic> = new DbStore<Dynamic>(data.name, this, o);
        return store;
    }

    static function areSchemasEqual(a:StructSchema, b:StructSchema):Bool {
        if (a.fields.length != b.fields.length)
            return false;
        for (name in a.fields.keys()) {
            var aField = a.fields[name],
                bField = b.fields[name];
            if (!aField.type.equals(bField.type)) {
                trace('${aField.type} != ${bField.type}');
                return false;
            }
            else if (aField.flags.toInt() != bField.flags.toInt()) {
                trace('${aField.flags.toInt()} != ${bField.flags.toInt()}');
                return false;
            }
        }
        if (a.indexes.length != b.indexes.length)
            return false;
        for (name in a.indexes.keys()) {
            var aIdx = a.indexes[name],
                bIdx = b.indexes[name];
            if (!aIdx.kind.equals(bIdx.kind)) {
                trace('${aIdx.kind} != ${bIdx.kind}');
                return false;
            }
        }
        if (a.type != null && b.type != null) {
            var ap = a.type.proto,
                bp = a.type.proto;
            
            if (ap != bp) {
                trace('${a.type.proto} != ${b.type.proto}');
                return false;
            }
            
            trace(a.type.info);
        }
        return true;
    }

    /**
      asynchronously acquire a Promise that resolves to the named table
     **/
    public function getTable<Row>(name: String):Promise<Option<DbStore<Row>>> {
        if (loadingStores.exists(name)) {
            return cast loadingStores[name];
        }

        var loaded:AsyncDeferred<DbStore<Row>, Dynamic> = Deferred.create();
        // var loading:AsyncDeferred<Option<DbStore<Row>>, Dynamic> = Deferred.create();

        var output:Promise<Option<DbStore<Row>>> = new Promise(function(resolve, reject) {
            var man = persistence.manifest.peek();
            if (stores.exists(name)) {
                var store:DbStore<Row> = cast stores.get(name);
                if (store._loadInProgress == null) {
                    store._load();
                }
                if (store._loadInProgress != null) {
                    store._loadInProgress.then(
                        _ -> resolve(Some(store)),
                        err -> reject(err)
                    );
                    return ;
                }
                
                return resolve(Some(cast stores[name]));
            }


            var decl = declaredTables.get(name);
            var tbl = man.tables.find(t -> t.name == name);
            switch [decl, tbl] {
                case [null, null]:
                    resolve(None);
                    // throw new pm.Error('Store "$name" not found!');

                case [{options:o}, null]:
                    var store:DbStore<Row> = new DbStore<Row>(name, this, o);
                    addStore(name, store);
                    store._load().map(store -> Some(cast store)).then(resolve, reject);
                    return ;

                case [a, b]: // both are present
                    var aSchema = a.schema,
                        bSchema = schemaFromData(b.structure);
                    
                    if (!areSchemasEqual(aSchema, bSchema)) {
                        //TODO update manifest
                        throw new pm.Error('$aSchema != $bSchema');
                    }

                    var store:DbStore<Row> = new DbStore<Row>(name, this, a.options);
                    addStore(name, store);
                    store._load().map(store -> Some(cast store)).then(resolve, reject);
                    
            }
        });
        
        loadingStores[name] = output;
        loadedStores[name] = loaded;

        output.then(function(o) {
            switch o {
                case Some(store):
                    loaded.done(store);

                case None:
                    loaded.fail('Not found!');
            }
        }, e -> loaded.fail(e));

        return output;
    }

    /**
      obtain a reference to the given table
      TODO: provide a table definition to this method as well, and intelligently merge/update the provided spec with the saved one when necessary
     **/
    public function table<Row>(name: String):DbStore<Row> {
        if (stores.exists(name)) {
            return (cast stores[name] : DbStore<Row>);
        }
        else {
            throw new pm.Error('table("$name") not found');
        }
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
        return executor.exec(
            name, 
            function() {
                return storage.unlink(
                    @:privateAccess store.options.filename
                );
            }
        )
        .map(function(_) {
            store.reset();
            stores.remove( name );
            return true;
        });
    }

    public function defineStore(name:String, schema:StructSchema, ?options:StoreOptions):Database {
        if (declaredTables.exists(name)) {
            throw 'Nope, sha';
        }

        if (options == null) options = {};

        var o:StoreOptions = {
            filename: nor(options.filename, Path.join([this.path, '$name.db'])),
            schema: schema,
            primary: schema.primaryKey,
            executor: executor,
            storage: storage
        };
        @:privateAccess schema._init();
        Arch.anon_copy(options, o);

        declaredTables[name] = {
            name: name,
            schema: schema,
            options: options
        };

        //TODO sync [this] manifest

        return this;
    }

    /**
      create and register a Store<Dynamic> on [this] Database
     **/
    public function createStore(name:String, ?schema:StructSchema, ?options:StoreOptions) {
        if (stores.exists(name)) {
            throw 'TODO!';
        }
        else {
            switch [name, schema, options] {
                case [name, null, null]:
                    var decl = declaredTables[name];
                    if (decl == null) {
                        throw 'Invalid call';
                    }
                    var store:DbStore<Dynamic> = new DbStore(name, this, decl.options);
                    store = addStore(name, store);
                    sync();
                    return store;

                case [_, _, _]:
                    if (!declaredTables.exists(name)) {
                        defineStore(name, schema, options);
                        return createStore(name, null, null);
                    }
                    else {
                        throw 'Invalid call';
                    }
            }
            throw 'Unreachable';

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
            return store;
        }
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

    /**
      opens a `Connection` to the given table
      @param table - the name of the table to connect to
     **/
    public function open<Item>(table: String):StoreConnection<Item> {
        // if [table] is not loaded
        if (!loadedStores.exists( table )) {
            if ( false ) {
                load( table );
            }

            throw 'iEatAss';
        }

        // if `table` has not yet been connected to
        if (!connections.exists( table )) {
            connections[table] = cast new StoreConnection<Item>(this, table);
        }

        return cast connections[table];
    }

/* === Variables === */

    @:noCompletion
    public var stores(default, null): Map<String, DbStore<Dynamic>>;
    public var declaredTables(default, null): Map<String, TableDeclaration>;
    
    public var path(default, null): String;

    public var executor(default, null): Executor;
    public var persistence(default, null): DatabasePersistence;
    public var storage(default, null): Null<Storage>;

    /**
      map of Promises to Store<?> objects which have already been loaded
     **/
    private var loadedStores: Map<String, Promise<DbStore<Dynamic>>>;
    /**
      map of Promises of Store<?> objects which are being resolved
     **/
    private var loadingStores: Map<String, Promise<Option<DbStore<Dynamic>>>>;
    private var connections: Map<String, StoreConnection<Dynamic>>;

    private var _isReady:Bool = false;
}

typedef TableDeclaration = {
    name: String,
    schema: SchemaInit,
    options: Null<StoreOptions>
};

typedef SchemaInit = StructSchema;

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
    public function find(q:Criterion<Item>, ?precompile:Bool):Promise<FindCursor<Item>> {
        return fmr.fn(_.find(q, precompile));
    }

    public function close():Promise<Bool> {
        return Promise.resolve(true);
    }

    public function insert(data: OneOrMany<Item>):Promise<DbStore<Item>> {
        return vfm.fn(_.insert(data.asMany()));
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

    private inline function vfm(f:DbStore<Item> -> Void):Promise<DbStore<Item>> {
        return fm(function(store) {
            f(store);
            return prom();
        });
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