package pmdb.core;

import pm.Noise;
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
import pmdb.core.schema.TableDeclaration;

import pm.async.*;

import haxe.io.Path;
import haxe.ds.Option;
import haxe.extern.EitherType as Or;

using pm.Strings;
using pm.Arrays;
using pm.Iterators;
using pm.Functions;
using pm.Options;

typedef DbOptions = {
	?path:String,
	?storage:Storage,
    ?preload: String,
    ?_init: Database -> Void
};

/**
  class which represents a collection of tables (`Store` instances) 
 **/
@:expose
class Database extends Emitter<String, Dynamic> {
    /* Constructor Function */
    public function new(options: DbOptions) {
        var FOOT:Array<Callback<Database>> = [];
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

        addEvent('ready');
        addEvent('closed');
        addEvent('error');

        if (nn(options._init))
            FOOT.push(options._init);

        /**
          [TODO] try implementing without using `defer`
         **/
        defer(function() {
            _openSelf(options.preload);
        });
        once('ready', function(_) {
            this._isReady = true;
        });
        on('error', function(error: Dynamic) {
            throw error;
        });

        /**
          process tail-deferred callbacks
         **/
        var recursionDepth:Int = -1;
        do {
            ++recursionDepth;
            if (recursionDepth >= 200) {
                throw new pm.Error('recursion depth limit exceeded');
            }

            for (f in FOOT.splice(0, FOOT.length)) {
                f(this);
            }
        }
        while (FOOT.length != 0);
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

    public function _openSelf(?tables: String):Promise<Database> {
        trace('calling persistence.open()');
        return Promise.async(function(done:Callback<Outcome<Database, Dynamic>>) {
            persistence.open(tables)
            .then(
                function(status) {
                    trace('persistence.open($tables) ${!status?"initialized database folder":"loaded database state"} successfully');
                    if (status) {
                        emit('ready', null);
                        done(Success(this));
                    }
                    else {
                        emit('ready', null);
                        done(Success(this));
                    }
                },
                function(error) {
                    done(Failure(error));
                }
            );
        }).handle(function(o) {
            switch o {
                case Failure(error):
                    emit('error', error);

                default:
            }
        });
    }

    private inline function exec<T>(f: Void->Promise<T>):Promise<Float> {
        return executor.exec('root', f);
    }

    /**
      synchronizes `this` Database
      @see DatabasePersistence.sync
     **/
    public function sync(?pos: haxe.PosInfos) {
        executor.exec('root', function() {
            return Promise.async(function(done) {
                persistence.sync().noisify().handle(done);
            });
        });
    }

    /**
      closes `this` Database, and ceases all communication with it
      [TODO] use lockFile to track whether a Database folder is being managed by an active process already
     **/
    public function close(?callback:(error:Null<Dynamic>)->Void):Promise<Noise> {
        return executor.exec('root', function() {
            return Promise.async(function(done) {
                persistence.close().handle(done);
            });
        }).noisify();
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
        return (promise.transform(function(outcome: pm.Outcome<Option<T>, Dynamic>) {
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
        // var tblp = getTable(name);
        trace('Database.load($name)');
        if (loadedStores.exists(name)) {
            return loadedStores.get(name);
        }
        else {
            var tblp2 = persistence.openStore({
                name: name,
                preload: true
            });
            return loadedStores[name] = tblp2;
        }
    }

    /**
      obtain a reference to the given table
      TODO: provide a table definition to this method as well, and intelligently merge/update the provided spec with the saved one when necessary
      TODO: throw special error when the referenced Store is not loaded, but *is* loading
     **/
    public function table<Row>(name: String):DbStore<Row> {
        if (stores.exists(name)) {
            return (cast stores[name] : DbStore<Row>);
        }
        else {
            throw new pm.Error('table("$name") not found');
        }
    }

    public function declarationFor(name: String) {
        return 
        if (declaredTables.exists(name))
            Some(declaredTables[name])
        else
            None;
    }

    /**
      add a `Store<Row>` object to the Database's internal registry of stores to manage
      [TODO] - create something like `pm.async.Callback.CallbackLink` for `Store<?>` objects, with an API something like `{heartbeat:Float, onSynced:Signal<?>, ...}`
     **/
    #if !debugSelf @:noCompletion #end
    public function _addStoreToRegistry<Row>(name:String, store:DbStore<Row>):DbStore<Row> {
        #if debug 
            assert((store is DbStore<Dynamic>));
            assert(pm.Helpers.nnSlow(this.stores) && !this.stores.exists(name));
            var storeDeclaration = declarationFor(name).extract(new pm.Error.InvalidOperation('RegistrationOfNonDeclaredStore', 'No "$name" store found in declared database namespace'));
            //TODO validate [store] against [storeDeclaration]
        #end

        if (!stores.exists(name))
            stores[name] = store;
        return store;
    }

    public function _hasStoreInRegistry(store: DbStore<Dynamic>):Bool {
        for (s in stores.iterator()) {
            if (s == store) {
                return true;
            }
        }
        return false;
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

        var d = createStoreDeclaration(name, schema, options);
        declaredTables.set(name, d);
        //TODO sync [this] manifest

        return this;
    }

    public function createStoreDeclaration(name, schema, ?options:StoreOptions):TableDeclaration {
		if (options == null)
			options = {};

		var o:StoreOptions = {
			filename: !options.filename.empty() ? Path.join([this.path, options.filename]) : Path.join([this.path, '$name.db']),
			schema: schema,
			primary: schema.primaryKey,
			executor: executor,
			storage: storage
		};

		Arch.anon_copy(options, o);
        trace(options);
        return new TableDeclaration(name, schema, o);
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

            throw new Error('err');
        }

        // if `table` has not yet been connected to
        if (!connections.exists( table )) {
            connections[table] = cast new StoreConnection<Item>(this, table);
        }

        return cast connections[table];
    }

    #if !debug @:noCompletion #end
    public dynamic function _putManifestInfo(i: ManifestData) {
        this._putManifestInfo = function(_) return ;
        // var state:Ref<ManifestData> = Ref.to(i);
        defer(() -> emit('manifest:infoavailable', i));
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