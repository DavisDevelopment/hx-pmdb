package pmdb.storage;

import pmdb.core.schema.TableDeclaration;
import pm.async.Callback;
import pm.Noise;
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
using pm.Numbers;

@:access(pmdb.core.Database)
class DatabasePersistence {
    public var db:Database;
    public var storage:IStorage;
    public var manifest:Persistent<ManifestData>;

    // private var afterOpenListeners: CallbackList<DatabasePersistence>;
    // private var beforeCloseListeners: CallbackList<DatabasePersistence>;

    /**  [Constructor Function]  **/
    public function new(database) {
        db = database;
        storage = db.storage;
    }

    private inline function getPath(?tail: String):pm.Path {
        var path:Path = new Path(db.path);
        if (!tail.empty())
            path = (path / tail);
        return path;
    }

    public function close() {
        return Promise.async(function(done) {
            trace("TODO: close store connections and shit");
            return done(Success(Noise));
        });
    }

    /**
      initiates the connection between the persisted state and [this] object
      attempts to read the manifest from the stored state, and mount the stored table-state
      if no stored state exists, a new one is initialized from the declared table-structure

      @returns true when an actual "restore" operation was performed successfully
     **/
    // private var openTails:CallbackList<
    public function open(?tables: String):Promise<Bool> {
        return Promise.async(function(done) {
            return openDirectory().next(function(o) {
                switch o {
                    case Success(_):
                        var tableSets = getStoreSets();
                        var tableSet = mergeStoreSets(tableSets);
                        tableSet = tableSet.filter(function(t) {
                            //TODO: filter preloads here
                            return true;
                        });
                        trace(tableSet);

                        return this.openTables(ImmutableList.fromArray(tableSet)).flatMap(function(stores) {
                            trace('Loaded (${stores.map(x -> x.name).join(',')})');
                            trace(stores.join(','));
                            //TODO verify the validity of the loaded data
                            return true;
                        });

                    case Failure("ENOENT"):
                        //opening directory failed
                        trace('Opening "${getPath()}" failed');
                        return this.buildDirectoryStructure().map(function(_) {
                            return false;
                        });

                    case Failure(e):
                        return Promise.reject(e);
                }
            }).handle(done);
        });
    }

    private function openTables(tables: ImmutableList<DbStore<Dynamic>>) {
        return openTableList(tables).flatMap(function(a) {

            return Promise.resolve(a.map(x -> x.store));
        });
    }

	/**
		accepts a list of `DbStore<?>` instances, and loads them all in parallel
		for each store, an attempt is made to load the stored state of the object
		if the load succeeds, the store is yielded
		if the load fails because there is no state stored, the store is yielded
		if the load fails because of any other error, that error is thrown
	**/
	function openTableList(tables:ImmutableList<DbStore<Dynamic>>, ?options) {
        Console.debug('called openTableList(...)');
		// var storage = new FileSystemStorage();
		var tablePromises = tables.map(function(store) @:privateAccess {
			return this.openTable(store).flatMap(function(status) {
                return {
                    name: status.store.name,
                    store: status.store,
                    schema: status.store.schema,
                    status: if (status.loaded) LoadStatus.Ok else LoadStatus.NoDataFile
                };
            });
		}).toArray();
		// storage = null;
        var allTablesPromise;
        if (tablePromises.length == 1) {
            allTablesPromise = tablePromises[0].map(x -> [x]);
        }
	    else {
            allTablesPromise = Promise.all(tablePromises);
        }
		// allTablesPromise.inspect();
		return allTablesPromise;
	}

	function openTableByName(name:String) {
		if (db.declaredTables.exists(name)) {
            var decl = db.declaredTables.get(name);
            var store = decl.createStoreInstance(db);

            /**
                [TODO] - refactor Store._load()
            **/
            return openTable(store).map(o -> o.store);
        }
        else {
            return Promise.reject('Store("$name) not found in db.declaredTables');
        }
	}

	function openTable(table:DbStore<Dynamic>):Promise<{store:DbStore<Dynamic>, loaded:Bool}> {
        if (!db._hasStoreInRegistry(table)) {
            db._addStoreToRegistry(table.name, table);
        }

		var result:Promise<{store:DbStore<Dynamic>,loaded:Bool}> = table.persistence.dataFileExists().failAfter(2000).next(function(o) {
            return switch o {
                case Failure(e): Promise.reject(e);
                case Success(false): Promise.resolve({store:table, loaded:false});
                case Success(true):
                    Console.debug('openTable(${table.name})  =>  loadTable(...)');
                    loadTable(table);
            };
        });
        return result.failAfter(5000);
	}

    inline function loadTable(table: DbStore<Dynamic>):Promise<{store:DbStore<Dynamic>, loaded:Bool}> {
        final startRowCount = table.size();
        Console.debug('calling table._load');
        var ltbl = table._load().failAfter(2000);
    
        return ltbl.map(x -> x.size()).flatMap(function(endRowCount: Int) {
            Console.success("Loaded ", endRowCount, " documents into ", table.name);
            if (startRowCount != 0)
                trace('[startRowCount=$startRowCount]');
            return switch [startRowCount, endRowCount] {
                case [0, 0]: Promise.resolve({store:table, loaded:false});
                case [0, count] if (count > 0): Promise.resolve({store:table, loaded:true});
                case _:
                    Promise.reject('$startRowCount, $endRowCount');
            }
        });
    }

    function openDirectory():Promise<Noise> {
        return Promise.async(function(done) {
            storage.exists(getPath()).then(function(hasDir) {
                if (hasDir) {
                    return done(Success(openManifest()));
                }
                else {
                    return done(Failure("ENOENT"));
                }
            }, error -> done(Failure(error)));
        })
        .noisify();
    }

    function openManifest(?update):ManifestData {
        if (this.manifest != null) return manifest.currentState;

        this.manifest = new Persistent<ManifestData>({
            version: '0.0.0',
            tables: []
        });
        // this.manifest.setFormat(Format.json());
        this.manifest.configure({
			name: this.getPath('manifest.json').toString(),
            format: cast Format.json()
        });
        this.manifest.open();
        if (update != null) {
            manifest.update(update);
        }
        manifest.commit();
        return this.manifest.currentState;
    }

    function buildDirectoryStructure():Promise<Noise> {
        return Promise.async(function(done) {
            storage.mkdirp(db.path).handle(function(outcome) {
                switch outcome {
                    case Success(true):
                        openManifest();
                        done(Success(Noise));
                        
                    case Failure(error):
                        done(Failure(error));

                    case Success(false):
                        done(Failure('failed to create directory'));
                }
            });
        })
        .transform(function(o):Outcome<ManifestData, Dynamic> {
            return switch o {
                case Success(_):
                    try Success(openManifest()) catch (e: Dynamic) Failure(e);

                case o: cast o;
            }
        }).flatMap(function(_) {
            var declarations = db.declaredTables.array();
            this.manifest.update(PUpdate.modCb(function(info: ManifestData) {
                final len = declarations.length;
                var stores = pm.Arrays.alloc(len);
                var storeManifests = pm.Arrays.alloc(len);

                for (index in 0...len) {
                    var store = declarations[index].createStoreInstance(db);
                    db._addStoreToRegistry(store.name, store);
                    stores[index] = store;
                    storeManifests[index] = Tools.toJson(store);
                    Console.success("registered <invert>", store.name, "</>");
                }

                storeManifests.sort(function(a, b) {
                    /**
                      [TODO] - use `timestamp` values for sorting
                     **/
                    return Reflect.compare(a.name, b.name);
                });

                info.tables = storeManifests;
            }));
            this.manifest.push();
            return Promise.resolve(Noise);
        }).noisify();
        
    }

    /**
      given a 2-dimensional list of store declarations, flatten it into the list of actual store instances which should be loaded
     **/
	private function mergeStoreSets(sets: Array<Array<TableDeclaration>>):Array<DbStore<Dynamic>> {
        assert(sets != null && sets.length != 0, new pm.Error('sets=$sets', 'InvalidArgument'));

		var swap = new Map<String, {left:Null<TableDeclaration>, right:Null<TableDeclaration>}>();

        for (a in sets[0])
            swap[a.name] = {left:a, right:null};
        
        for (b in sets[1]) {
            if (swap.exists(b.name))
                swap[b.name].right = b;
            else
                swap[b.name] = {left:null, right:b};
        }

        var merged = new Map();
        var added = new Map();
        var removed = new Map();
        
        for (name=>pair in swap) {
            switch pair {
                case {left:a, right:b}:
                    a.schema.pack();
                    b.schema.pack();
                    if (StructSchema.areSchemasEqual(a.schema, b.schema)) {
                        merged[b.name] = b;
                    }
                    else {
                        throw new pm.Error('Unhandled inequality');
                        Sys.exit(0);
                    }

                case {left:a, right:null}:
                    added[a.name] = a;

                case {left:null, right:a}:
                    removed[a.name] = a;

                case null|{left:null, right:null}:
                    throw new pm.Error('Unhandled nullness');
            }
        }

        /**
          [TODO] handle `removed` and `added`
         **/
        
        var result = [for (d in merged) d.createStoreInstance(db)];
        return result;
	}

	private inline function getStoreSets():Array<Array<TableDeclaration>> {
		assert(manifest != null && db != null);
		var storeSets = new Array();
        for (d in db.declaredTables)
            trace(d.schema.indexes.keyArray());

        var declaredList = new Array();
	    for (d in db.declaredTables) {
            declaredList.push(d);
        }
        storeSets.push(declaredList);

        var manifestStores = new Array();
        for (l in manifest.currentState.tables) {
            // var store = new TableDeclaration(l.name, StructSchema.ofJsonState(l.structure));
            var store = db.createStoreDeclaration(l.name, StructSchema.ofJsonState(l.structure));
            manifestStores.push(store);
        }
        storeSets.push(manifestStores);
		return storeSets;
	}

    /**
      initiate synchronization of all opened Store instances, and resolve when all are complete
     **/
    public function sync():Promise<Bool> {
        trace('TODO: sync all stores');
        syncManifest();
        return Promise.resolve(true);
    }

    function syncManifest() {
        var tables:Array<DbStore<Dynamic>> = [for (store in db.stores) store];
		this.manifest.update(PUpdate.modCb(function(info:ManifestData) {
			final len = tables.length;
			var storeManifests = pm.Arrays.alloc(len);

			for (index in 0...len) {
				var store = tables[index];
				storeManifests[index] = Tools.toJson(store);
			}

			storeManifests.sort(function(a, b) {
				return Reflect.compare(a.name, b.name);
			});

			info.tables = storeManifests;
		}));
		this.manifest.push();
    }

    /**
      prepare [this] persistence instance for garbage collection
     **/
    public function release() {
        throw 'Not Implemented';
    }

	public function openStore(options: {?path:String, ?name:String, ?preload:Bool}):Promise<DbStore<Dynamic>> {
		return Promise.reject("Not Implemented");
    }

	public function getOptStoreAsync(name:String, autoOpen:Bool = false):Promise<Option<DbStore<Dynamic>>> {
		return Promise.reject("Not Implemented");
    }
}

class Tools {
	public static function jsonTables(db:Database):Array<TableData> {
		var tableList = db.declaredTables.iterator().map(d -> {
			jsonTable(d.name, d.options.filename, nor(d.options.schema, d.schema));
		});
		return tableList.array();
	}

    public static inline function toJson(store: DbStore<Dynamic>):TableData {
        return jsonTable(
            store.name,
            store.persistence.filename,
            store.schema
        );
    }

	public static inline function jsonTable(name:String, pathName:String, structure:StructSchema):TableData {
		return {
			name: name,
			pathName: pathName,
			structure: jsonStructure(structure)
		};
	}

	public static inline function jsonStructure(schema:StructSchema) {
		return schema.toJson();
	}
}

typedef ManifestData = {
    version: String,
    tables: Array<TableData>
};

typedef TableData = {
	var name:String;
	var pathName:String;
	var structure:TableStructureData;
};

typedef TableStructureData = pmdb.core.schema.Types.JsonSchemaData;

enum abstract LoadStatus (Int) from Int to Int {
    var NoDataFile = -1;
    var NoSavedState;
    var Ok;

    public inline function validate() {
        var me:Null<Int> = cast this;
        assert(me != null && !me.isNaN() && me.isFinite(), new pm.Error('Invalid Integer $this'));
        switch this {
            case NoDataFile, NoSavedState, Ok:
                //

            case other:
                throw new pm.Error('Invalid LoadStatus: $other');
        }
    }

    public inline function isNil():Bool {
        return switch this {
            case NoDataFile|NoSavedState: true;
            default: false;
        }
    }
}