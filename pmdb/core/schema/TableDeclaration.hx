package pmdb.core.schema;

import pmdb.core.Store;
import pmdb.core.Database;
import pmdb.storage.DatabasePersistence;
import pm.Path;

// var schemas = [for (tbl in manifest.tables) tbl.name=>StructSchema.ofJsonState(tbl.structure)];
@:structInit
class TableDeclaration {
	public var name:String;
	public var schema:SchemaInit;
	public var options:Null<StoreOptions>;

	public function new(name, schema:SchemaInit, ?options:Null<StoreOptions>) {
		this.name = name;
		this.schema = schema;
		this.options = nor(options, {});
	}

	/**
		@param db - the `Database` object to which the Store instance should be attached
	**/
	public inline function createStoreInstance(db:Database):DbStore<Dynamic> {
		return new DbStore(name, db, buildTableInit(db, name, schema, options));
	}

	static function buildTableInit(db:Database, name, schema:StructSchema, options:StoreOptions) {
		var opts:StoreOptions = Reflect.copy(options);
		var o:StoreOptions = {
			filename: !options.filename.empty() ? Path.join([db.path, options.filename]) : Path.join([db.path, '$name.db']),
			schema: schema,
			primary: schema.primaryKey,
			executor: db.executor,
			storage: db.storage
		};

		Arch.anon_copy(opts, o);
		return opts;
	}
}

typedef SchemaInit = StructSchema;