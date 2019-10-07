package pmdb.storage;

import pm.ImmutableList;
import pm.Pair;
import haxe.Json;
import Type.ValueType;
import pmdb.core.FrozenStructSchema;
import pmdb.storage.Persistence.RawStoreData;
import pmdb.core.FrozenStructSchema.FrozenStructSchemaInit;
import pmdb.core.ds.Outcome;
import pmdb.core.Object;
import pmdb.core.Store;
import pmdb.ql.ts.DataType;
import pmdb.core.ValType;

import haxe.io.Bytes;
import haxe.ds.Option;
import haxe.ds.Either;

import pmdb.storage.IPersistence;
import pmdb.storage.IStorage;
import pmdb.storage.io.Persistent;
import pmdb.storage.Format;
import pmdb.core.Database;
import pmdb.core.DbStore;
import pmdb.core.StructSchema;
import pm.Path;
import pm.async.*;

using pm.Strings;
using pm.Arrays;
using pm.Iterators;
using pm.Functions;
using pm.Outcome;
using pm.Options;
using pm.async.Async;
using pm.Helpers;

/**
  [TODO]: set 'enumerable' flag to `false` for private fields on js target
 **/
class DatabasePersistence {
    public function new(database) {
        this.owner = database;
        this.storage = owner.storage;
        
        this.manifest = new Persistent({
            version: 1,
            tables: new Array()
        });
        manifest.configure({
            name: manifestPath.toString(),
            format: cast Format.json()
        });
        // manifest.setFormat(cast Format.json());
        // manifest.setPath(manifestPath);
        // manifest.onOpened = function(info) {
            //
        // };
        manifest.open();
    }

/* === Methods/Functions === */

    public function open(?preloadTables: String):Promise<Bool> {
        return _mount_({
            preloadTables: preloadTables
        }).map(function(map) {
            //validate [map]
            trace([for (name=>store in map) name=>store.size()]);
            return true;
        });
    }

	/**
		build a Store<?> object from the given TableData
	**/
	function tableFromData(data:TableData):DbStore<Dynamic> {
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
			filename: Path.join([owner.path, '${data.name}.db']),
			schema: schema,
			inMemoryOnly: false,
			primary: schema.primaryKey,
			executor: owner.executor,
			storage: storage
		};
		var store:DbStore<Dynamic> = new DbStore<Dynamic>(data.name, owner, o);
		return store;
	}

    function _mount_(options: {?preloadTables: String}) {
        var tablesToPreload:Array<String> = switch options.preloadTables {
            case null|'': [];
            case '*'|'<all_tables>': ['<all_tables>'];
            case s:
                var re:EReg = ~/\s*,\s*/g;//).split()
                re.match(s)?re.split(s).map(x -> x.trim()):[s];
        };

        return directoryStructure().inspect().flatMap(function(ds) {
            switch ds {
                case {loadStores:false, manifest:i}|{manifest:i={tables:[]|null}}:
                    return mountManifest(i, false);

                case {manifest:manifest} if (tablesToPreload.empty()):
                    return mountManifest(manifest, false);

                case {manifest:manifest}:
                    return mountManifest(manifest, true, switch tablesToPreload {
                        case ['<all_tables>']: null;
                        case _: tablesToPreload;
                    });
            }
        });
    }

    function mountManifest(manifest:ManifestData, autoload:Bool, ?tables:Array<String>):Promise<Map<String, DbStore<Dynamic>>> {
        var pairs = mountTablesFromManifest(manifest);
        var doPreload = ImmutableList.fromArray([]), noPreload = ImmutableList.fromArray([]);
        for (pair in pairs) {
            if (tables != null && tables.has(pair.left.name)) {
                doPreload = pair & doPreload;
            }
            else {
                noPreload = pair & noPreload;
            }
        }

        trace(doPreload.map(p -> {
            name: p.left.name,
            shape: p.right.schema.toString()
        }));

        if (!autoload) {
            return Promise.resolve(mapTablesPairs(pairs));
        }
        else {
            /**
              [TODO] also mount the defined tables
             **/
            var promise = openTablesPairs(doPreload);
            return promise;
        }
    }

    inline function mapTablesPairs(pairs: Array<pm.Pair<TableData, DbStore<Dynamic>>>) {
        return [for (p in pairs) p.left.name => p.right];
    }

    @:access(pmdb.core.Store)
    function openTablesPairs(pairs: Array<Pair<TableData, DbStore<Dynamic>>>) {
        var tableNames:Array<String> = new Array();
        var tablePromises:Array<Promise<DbStore<Dynamic>>> = new Array();
        
        for (x in pairs) {
            var store:DbStore<Dynamic> = x.right,
                path:pm.Path = new pm.Path(store.options.filename);
            tableNames.push(x.left.name);
            var tablePromise = canLoadStoreAt(path).inspect().flatMap(function(canLoad) {
                if (canLoad) {
                    return Promise.async(loadStoreAt.bind(store, x.left.pathName)).map(b -> Some(b));
                }
                else {
                    return Promise.resolve(None);
                }
            }).flatMap(function(o) {
                switch o {
                    case Some(true)|None:
                        return Promise.resolve(store);
                    
                    case Some(false):
                        return Promise.reject(new pm.Error('Failed to load Store'));
                }
            });
            tablePromises.push(tablePromise);
        }

        trace('starting to load stores...');
        return Promise.all(tablePromises).map(function(stores) {
            var res = [for (i in 0...stores.length) tableNames[i]=>stores[i]];
            for (n=>s in res) {
                trace('${n} is ${(@:privateAccess s.ioLocked)?"":'not '} locked');
            }
            return res;
        });
    }

    function mountTablesFromManifest(m: ManifestData):Array<pm.Pair<TableData, DbStore<Dynamic>>> {
        var out = pm.Arrays.alloc(m.tables.length);
        for (i in 0...m.tables.length) {
            var t = m.tables[i];
            var store = owner.addStore(t.name, tableFromData(t));
            @:privateAccess store.options.filename = t.pathName;
            out[i] = new pm.Pair(t, store);
        }
        return out;
    }

    /**
      ensures that the expected directory structure exists, and then loads it
     **/
    inline function directoryStructure() {
        return storage.exists(owner.path).flatMap(b -> b ? mountDirectoryStructure() : buildDirectoryStructure());
    }

    /**
      loads Database state from directory structure
      @return the manifest-state and whether or not stores should be auto-loaded
     **/
    function mountDirectoryStructure():Promise<{manifest:ManifestData, loadStores:Bool}> {
        var manifestPath:Path = (new Path(owner.path) / 'manifest.json');
        
        return storage.exists(manifestPath)
        .flatMap(function(canRead) {
            if (canRead) {
                this.manifest.open();
                var manifest:ManifestData = this.manifest.currentState;
                Console.debug(manifest);

                return Promise.resolve({
                    manifest: manifest,
                    loadStores: true
                });
            }
            else {
                return buildDirectoryStructure();
            }
        });
    }

    /**
      initializes the directory structure in which Databases are stored, and those objects which track that data
     **/
    function buildDirectoryStructure() {
        #if debug trace('building directory structure'); #end
        return storage.mkdirp(owner.path)
        .flatMap(function(created) {
            if (created) {
                // create a default manifest object
                var defaultManifest:ManifestData = {
                    version: 1,
                    tables: new Array()
                };

                // fill out the manifest with the Database meta state
                applyDeclaredStructureToManifest(defaultManifest);
                
                // update the manifest Persistent
                this.manifest.update(defaultManifest);
                this.manifest.commit();

                return Promise.resolve({
                    manifest: this.manifest.currentState,
                    loadStores: false
                });
            }
            else {
                trace('error');
                return Promise.reject('Directory not created');
            }
        });
    }

    inline function applyDeclaredStructureToManifest(manifest: ManifestData) {
        var agg = this.aggStoreList().sort((a, b) -> Reflect.compare(a.name, b.name)).toArray();
        for (decl in agg) {
            manifest.tables.push({
                name: decl.name,
                pathName: decl.pathName,
                structure: decl.structure
            });
        }
    }

    /**
      Checks for presence of store-entries in storage (this will typically mean table files on the filesystem).
      If found, they are parsed for the Store's metadata, which is diffed against the existing declaration if one exists.
      (TODO: define conflict-resolution method)
      If `options.preload` is `true`, then the store-entries are also parsed for the store's documents, which are inserted onto the empty `Store<?>` instance
      The `Store<?>` instance that was (or was ultimately not) operated upon is returned
     **/
    public function openStore(options: {?path:String, ?name:String, ?preload:Bool}):Promise<DbStore<Dynamic>> {
        assert(options.name != null, 'Invalid options for openStore');
        options.preload = nor(options.preload, true);
        options.path = nor(options.path, '${options.name}.db');
        
        // define convenience variables
        final name:String = options.name;
        final path:String = options.path;
        var tableOptions:StoreOptions = {},
            tableSchema:Either<StructSchema, FrozenStructSchemaInit> = Right({fields:[],indexes:[],options: {}});
        Console.log({
            name:name,
            path: path,
            tableOptions: tableOptions,
            tableSchema: tableSchema
        });
        /*
        initiate seriously overly complicated retrieval of declaration data
        */
        inline function use_declaration(d: TableDeclaration) {
            if (d.options != null) 
                Arch.clone_object_onto(d.options, tableOptions);
            if (d.schema != null) {
                tableSchema = Left(d.schema);
            }
        }
        
        switch owner.declarationFor(name) {
            case Some(v):
                use_declaration(v);

            case None:
                //
        }
        
        // build the `options` object used to construct the Store
        inline function storeInit():Dynamic {
            var o:Doc = (cast {
                name: name
            } : Doc);
            o.append(Arch.clone(tableOptions, ShallowRecurse));
            (cast o : StoreOptions).schema = (switch tableSchema {
                case Left(v): v;
                case Right(v): FrozenStructSchema.build(v).thaw();
            });
            return untyped o;
        }

        // returns the Store<?> instance to be operated on
        var _store:Null<DbStore<Dynamic>> = null;
        function store():DbStore<Dynamic> {
            if (_store != null) return _store;
            if (_store == null && owner.stores.exists(name)) {
                var pStore:DbStore<Dynamic> = cast owner.stores.get(name);
                _store = pStore;
                return _store;
            }

            if (_store == null && !owner.stores.exists(name)) {
                assert(!name.empty() && tableSchema != null && tableOptions != null); // sanity check #1

                var store_config = storeInit();
                var store_object = newStoreInstance(store_config);
                trace('created store object');
                // Console.log(store_object);
                
                assert((store_object is DbStore<Dynamic>), new pm.Error('Expected DbStore<?>, got ${Type.typeof(store_object)}'));

                owner.stores.set(name, store_object);
                _store = store_object;
                return _store;
            }

            throw new pm.Error.WTFError();
        }


        return new Promise(function(_return) {
            //
            this.loadStoreAt(store(), path, function(out) {
                // trace(out.getName());
                // Console.examine(out);
                switch out {
                    case Failure(err):
                        throw err;
                    case Success(_):
                        _return(_store);
                    // case Success(true):
                        // _return()
                }
            });
        });
    }

    function newStoreInstance(init: StoreOptions & {?name:String}):DbStore<Dynamic> {
        return new DbStore<Dynamic>(init.name, this.owner, init);
    }

    /**
      what in the actual fuck?
     **/
	function loadStoreAt(store:Store<Dynamic>, filePath:String, done:Callback<Outcome<Bool, Dynamic>>) {
		/**
			report this load as a failure
		**/
		function reject(err:Dynamic) {
			done(Failure(err));
		}

		/**
			NOTE: this nested function is where the primary "load the Store's state from storage" behavior is defined
		**/
		inline function LoadStoreRoutine(store:Store<Dynamic>):{function handle(f:Callback<Outcome<Store<Dynamic>, Dynamic>>):Void;} {
			return {
				var p = store.persistence.loadDataStore(store, {filename: filePath});
                // p.inspect();
				{handle: function(cb) p.handle(cb)};
			};
		}

		function doLoad() @:privateAccess {
			LoadStoreRoutine(store).handle(o -> switch o {
				case Success(result):
					done(Success(result != null));

				case Failure(error):
					done(Failure(error));
			});
		}

		asyncIf(canLoadStoreAt(filePath), doLoad, function() done(Success(false)));
	}

    static function asyncIf(cond:Promise<Bool>, t:Void->Void, ?f:Void->Void) {
        function _(b:Bool) {
            if (b)
                t();
            else if (f != null)
                f();
       }
       cond.then(_);
    }

    static function loadStoreFromStorage_base<Cooked>(self, o:{?store:DbStore<Dynamic>, ?filePath:String, ?storage:Storage}, cook, applyOntoStore, onComplete:Callback<Option<Dynamic>>) {
        var tbl:DbStore<Dynamic> = o.store;
        assert(tbl != null, new pm.Error('Invalid \'store\' option'));

        var tblPersistence = tbl.persistence,
            tblStorage = nor(o.storage, tbl.persistence.storage),
            path:String = o.filePath;
        
        /**
          TODO: make async
         **/
        (tblPersistence.loadRawStoreData({
            filename: path
        })
        // .inspect()
        .transform(o -> switch o {
            case Failure(error):
                throw error;
            case Success(null):
                Success(None);
            case Success(raw):
                var transform:RawStoreData<Storage> -> Cooked = cook;
                var storeDataTransformation:Outcome<Null<Cooked>, Dynamic> =
                    try Success(transform(raw))
                    catch (e: Dynamic) Failure(e);
                
                // Success(Some(transform(raw)))
                switch storeDataTransformation {
                    case Success(cooked):
                        //TODO write the data onto [tblStorage]
                        applyOntoStore(tbl, cooked);
                        Success(Some(tbl));
                        
                    case Failure(error):
                        Failure(error);
                }
        }) : Promise<Option<DbStore<Dynamic>>>)
        .handle(function(o) switch o {
            case Failure(e)|Success(Some(e)):
                onComplete(Some(e));
            // case Success(Some)
            case Success(None):
                onComplete(None);
            // case Failure(error):
        });
        // });
    }

    /**
      TODO: make promise-ilicious
     **/
    function loadStoreFromStorage(options) {
        return new Promise(function(done) {
            var prepare = Functions.identity;
            //TODO
            function handle(store:DbStore<Dynamic>, data:RawStoreData<Dynamic>) {
                store.insertMany(data.docs);
            }
            loadStoreFromStorage_base(this, options, prepare, handle, function(o) {
                switch o {
                    case Some(err):
                        throw err;
                    case None:
                        //
                }
                return done(options.store);
            });
        });
    }

    private var preloadingStores:Map<String, Promise<DbStore<Dynamic>>> = new Map();
    function preloadStoreAt(store:DbStore<Dynamic>, filePath:String):Promise<DbStore<Dynamic>> {
        var key:String = nor(filePath, @:privateAccess store.options.filename);
        if (preloadingStores.exists(key)) {
            return preloadingStores[key];
        }
        else {
            preloadingStores[key] = new Promise<DbStore<Dynamic>>(function(done:Callback<Outcome<DbStore<Dynamic>, Dynamic>>) @:privateAccess {
                if (store.isLoaded) {
                    done(Success(store));
                }
                else {
                    if (store._loadInProgress == null) {
                        store._loadInProgress = cast loadStoreFromStorage({
                            store: store,
                            filePath: filePath
                        });
                    }
                    store._loadInProgress.handle(function(loadOutcome) switch loadOutcome {
                        case Success((cast _ : DbStore<Dynamic>) => store): done(Success(store));
                        case Failure(err): done(Failure(err));
                    });
                }
            });
            return preloadingStores[key];
        }
    }

    function canLoadStoreAt(path: String):Promise<Bool> {
        var out:Promise<Bool> = new Promise(function(done) {
            var doesExist = storage.exists(path);
            doesExist.handle(o -> switch o {
                case Success(true):
                    storage.size(path).handle(o -> switch o {
                        case Success(len) if (len > 0):
                            done(true);

                        default:
                            trace('file at "$path" is empty');
                            done(false); 
                    });

                case Success(false):
                    done(false);

                case Failure(error):
                    trace(error);
                    trace('checking whether "$path" exists failed');
                    done(false);
            });
        });
        return out;
    }

    public function sync() {
        manifest.update({
            version: 1,
            tables: aggStoreList().toArray()
        });
        manifest.commit();

        // Callback.defer(manifest.commit);
    }

    function aggStoreList() {
        var tableNames = [];
        var results = ImmutableList.fromArray([]);
        for (store in owner.declaredTables) {
            tableNames.push(store.name);
            var data = {
                name: store.name,
                pathName: store.options.filename,
                structure: Tools.jsonStructure(store.schema)
            };
            results = data & results;
        }
        for (store in owner.stores) {
            if (!tableNames.has(store.name)) {
                results = Tools.jsonTable(store.name, '', store.schema) & results;
            }
        }
        return results;
    }

    public function release() {
        manifest.commit();
        // manifest.release();
    }

    public function getOptStoreAsync(name:String, autoOpen:Bool=false):Promise<Option<DbStore<Dynamic>>> {
        mountDeclaredStoreIfNecessary(name);
        var p = getMountedStore(name, autoOpen);
        p.handle(function(o) {
            trace('' + o);
        });
        return p;
    }

    public function getMountedStore(name:String, autoOpen:Bool=true):Promise<Option<DbStore<Dynamic>>> {
        if (owner.stores.exists(name)) {
            var store:Null<DbStore<Dynamic>> = owner.stores.get(name);
            if (store == null) {
                return Promise.reject(new Error('null Store<"$name">'));
            }
            else @:privateAccess {
                if (!autoOpen || store.isLoaded) {
                    return Promise.resolve(Some(store));
                }
                else {
                    if (store._loadInProgress == null)
                        store._load();
                    if (store._loadInProgress == null) {
                        return Promise.reject(new Error('Store<"$name"> load failed to start'));
                    }
                    return store._loadInProgress.map(function(store) {
                        return Some(cast store);
                    });
                }
            }
        }
        else {
            return Promise.resolve(None);
        }
    }

    public function mountDeclaredStore(name:String) {
        if (owner.declaredTables.exists(name)) {
            var decl = owner.declaredTables[name];
            var store:DbStore<Dynamic> = new DbStore(decl.name, owner, decl.options);
            owner.addStore(name, store);
        }
        else {
            throw new Error('NDECL: Store "$name" not declared');
        }
    }
    
    public function mountDeclaredStoreIfNecessary(name: String) {
        if (!owner.stores.exists(name)) {
            mountDeclaredStore(name);
        }
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
    public static function jsonTables(db: Database):Array<TableData> {
        var tableList = db.declaredTables.iterator().map(d -> {
            jsonTable(
                d.name,
                d.options.filename,
                nor(d.options.schema, d.schema)
            );
        });
        return tableList.array();
    }
    public static inline function jsonTable(name:String, pathName:String, structure:StructSchema) {
        return {
            name: name,
            pathName: pathName,
            structure: jsonStructure(structure)
        };
    }
    public static inline function jsonStructure(schema: StructSchema) {
        return schema.toJson();
    }
}

typedef ManifestData = {
    /**
      [TODO] change [version] to some sort of SemVer String
     **/
    var version: Int;
    var tables: Array<TableData>;
};

typedef TableData = {
    var name : String;
    var pathName : String;
    var structure : TableStructureData;
};

typedef TableStructureData = pmdb.core.StructSchema.JsonSchemaData;