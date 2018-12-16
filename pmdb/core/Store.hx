package pmdb.core;

import tannus.ds.Lazy;

import pmdb.ql.types.*;
import pmdb.ql.ts.*;
import pmdb.ql.ts.DataType;
import pmdb.core.ds.AVLTree;
import pmdb.ql.ast.BoundingValue;
import pmdb.core.ds.*;
import pmdb.core.*;
import pmdb.core.StructSchema;
import pmdb.core.query.Criterion;
import pmdb.core.query.Mutation;
import pmdb.ql.QueryIndex;
import pmdb.core.query.StoreQueryInterface;
import pmdb.core.Query;

import haxe.ds.Either;
import haxe.extern.EitherType;
import haxe.ds.Option;
import haxe.PosInfos;

import haxe.macro.Expr;
import haxe.macro.Context;

import tannus.math.TMath as M;
import pmdb.core.Error;
import Slambda.fn;
import Std.is as isType;
import pmdb.core.Assert.assert;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.ds.DictTools;
using tannus.ds.MapTools;
using tannus.async.OptionTools;
using tannus.FunctionTools;
using pmdb.ql.ts.DataTypes;

/**
  Store<Item> - stores a "table" of documents, indexed by their various keys
  based heavily on louischatriot's "nedb" [DataStore](https://github.com/louischatriot/nedb/blob/master/lib/datastore.js)
 **/
class Store<Item> {
    /* Constructor Function */
    public function new(options: StoreOptions):Void {
        this.options = options;

        indexes = new Map();
        schema = null;
        if (options.schema != null)
            schema = options.schema;

        _init_();

        q = new StoreQueryInterface( this );
    }

/* === Internal Methods === */

    /**
      initialize [this] Store
     **/
    private function _init_() {
        _init_indices_();
    }

    /**
      initialize [this] Store's indices
     **/
    private function _init_indices_():Void {
        /* == Primary Index == */
        assert(schema != null, new Error('Schema must be provided'));

        for (info in schema.indexes) {
            //_addIndexToCache(_buildIndex( info ));
            if (schema.hasField(info.name)) {
                addSimpleIndex(info.name);
            }
        }
    }

    /**
      prepare the given Item for insertion into [this] Store
     **/
    private inline function prepareForInsertion(doc: Item):Item {
        return cast schema.prepareStruct(cast doc);
    }

    /**
      generate a new, universally unique id
     **/
    private function createNewId():String {
        return Arch.createNewIdString();
    }
    //TODO implement this in DocumentSchema
    private var pkcounter:Int = 0;
    private function incrementId():Int {
        return pkcounter++;
    }

    /**
      build and return an index
     **/
    private function buildIndex(o: StoreIndexOptions):Index<Any, Item> {
        var idx = new Index({
            fieldName: o.name,
            fieldType: o.type,
            unique: o.unique,
            sparse: o.sparse
        });
        return cast idx;
    }

    private function _persist() {
        //TODO
        // this method is a placeholder for an actual persistence implementation
    }

    private function _syncCacheWithSchema() {
        //
    }

    /**
      called when a new field is added to the schema, on an existing Store instance
     **/
    private function _fieldAdded(field: StructSchemaField) {
        //_eachRow(function(row: Item) {
            
        //})
    }

    private function _fieldUpdated(oldField:StructSchemaField, newField:StructSchemaField) {
        //TODO resolve changes
    }

    private function _fieldDropped(field: StructSchemaField) {
        //
    }

    private inline function _eachRow(fn: Item -> Void) {
        inline pid.getAll().iter( fn );
    }

/* === Instance Methods === */

    /**
      get all data from [this] Store
     **/
    public function getAllData():Array<Item> {
        return pid.getAll();
    }

    /**
      gg (bruh)
     **/

    /**
      insert one or more new documents into [this] Store
     **/
    public function insert(doc: OneOrMany<Item>):Void {
        _insert( doc );
    }

    /**
      insert a new document into [this] Store
     **/
    public function insertOne(doc: Item):Item {
        var preparedDoc:Item = prepareForInsertion( doc );
        addOneToIndexes( preparedDoc );
        _persist();
        return preparedDoc;
    }

    /**
      insert multiple documents into [this] Store
      @param allowPartial whether all inserts must complete without errors. 
      When <code>true</code>, only the documents for which the insertion failed are returned.
      Otherwise, all inserted documents are returned
     **/
    public function insertMany(docs:Array<Item>, allowPartial:Bool=false):Array<Item> {
        if ( allowPartial ) {
            var failed = [];
            for (doc in docs) {
                try {
                    var preparedDoc = prepareForInsertion( doc );
                    addOneToIndexes( preparedDoc );
                }
                catch (err: Dynamic) {
                    failed.push( doc );
                }
            }
            _persist();
            return failed;
        }
        else {
            // prepare the lot for insertion
            var preparedDocs:Array<Item> = docs.map(o -> prepareForInsertion(o));

            addManyToIndexes( preparedDocs );
            _persist();

            return preparedDocs;
        }
    }

    /**
      insert
     **/
    private function _insert(doc: OneOrMany<Item>) {
        try {
            _insertIntoCache( doc );
            _persist();
        }
        catch (err: Dynamic) {
            throw err;
        }
    }

    /**
      insert the given value(s) into [this] DataStore
     **/
    private function _insertIntoCache(doc: OneOrMany<Item>) {
        if (doc.isMany()) {
            insertMany(doc);
        }
        else {
            insertOne(doc.asOne());
        }
    }

    /**
      shouldn't really ever be needed, but here it is, for convenience
     **/
    public function index<K>(fieldName: String):Null<Index<K, Item>> {
        return (cast indexes.get( fieldName ) : Index<K, Item>);
    }

    /**
      add a new Field to the schema which describes the structures to be stored in [this] Store
     **/
    public function addField(name:String, ?type:ValType, ?flags:Array<FieldFlag>, ?opts:{}) {
        var prev = schema.field( name );

        var curr = schema.addField(name, type, flags);

        if (prev == null) {
            _fieldAdded( curr );
        }
        else {
            _fieldUpdated(prev, curr);
        }
    }

    public function dropField(name: String) {
        //TODO register the field removal..
        schema.dropField( name );
    }

    /**
      convenience method for creating a new Index
     **/
    public function addSimpleIndex<T>(fieldName: EitherType<String, StructSchemaField>):Index<T, Item> {
        var field = (fieldName is StructSchemaField) ? (fieldName : StructSchemaField) : schema.field(cast fieldName);
        schema.addIndex({
            name: field.name,
            type: field.type
        });

        var index = new Index({
            fieldName: field.name,
            fieldType: field.type,
            unique: field.unique,
            sparse: field.isOmittable()
        });
        
        _addIndexToCache( index );

        return cast index;
    }

    /**
      ensure the existence of an Index on [this] Store
     **/
    public function ensureIndex(opts: StoreIndexOptions):Index<Any, Item> {
        // sanity checks
        if (opts.name.empty())
            throw new Error('cannot create and Index without a fieldName');

        if (indexes.exists( opts.name )) {
            indexes[opts.name].insertMany(getAllData());
            return indexes[opts.name];
        }

        // build the index
        _addIndexToCache(buildIndex( opts ));

        // return the created index
        return indexes[opts.name];
    }

    private function _addIndexToCache(index:Index<Any, Item>) {
        indexes[index.fieldName] = index;
        index.insertMany(getAllData());
    }

    /**
      build an actual index instance from the given definition
     **/
    private function _buildIndex(idxDef:IndexDefinition):Index<Any, Item> {
        //TODO actually support multiple indexing algorithms, and compound indexes
        switch ([idxDef.kind, idxDef.algorithm]) {
            case [IndexType.Simple({pathName:key}), IndexAlgo.AVLIndex]:
                var field = schema.field( key );
                assert(field != null, 'Cannot index by an undefined field ("$key")');
                return new Index({
                    fieldName: key,
                    fieldType: field.type,
                    unique: field.unique,
                    sparse: field.isOmittable()
                });

            case [type, algo]:
                throw new Error('IndexDefinition unsupported (type = $type, algorithm = $algo)');
        }
    }

    /**
      remove an Index from [this] Store
     **/
    public function removeIndex(fieldName: String) {
        assert(fieldName != primaryKey, 'Cannot drop primary key');
        indexes.remove( fieldName );
        schema.removeIndex( fieldName );
    }

    /**
      add a document to [this] Store
     **/
    public function addOneToIndexes(doc: Item) {
        var failingIndex:Int = -1,
        error: Dynamic = null,
        keys = indexes.keyArray();

        for (i in 0...keys.length) {
            try {
                indexes[keys[i]].insertOne( doc );
            }
            catch (e: Dynamic) {
                failingIndex = i;
                error = e;
                break;
            }
        }

        if (error != null) {
            for (i in 0...failingIndex) {
                indexes[keys[i]].removeOne( doc );
            }

            throw error;
        }
    }

    /**
      remove a document from [this] Store
     **/
    public function removeOneFromIndexes(doc: Item) {
        for (i in indexes)
            i.removeOne( doc );
    }

    /**
      add many documents to [this] Store
     **/
    public function addManyToIndexes(docs: Array<Item>) {
        var failingIndex:Int = -1,
        error: Dynamic = null,
        keys = indexes.keyArray();

        for (i in 0...keys.length) {
            try {
                indexes[keys[i]].insertMany( docs );
                trace('successfully inserted ${docs.length} documents into "${keys[i]}"');
            }
            catch (e: Dynamic) {
                failingIndex = i;
                error = e;
                trace('attempted insertion of the given ${docs.length} documents failed');
                break;
            }
        }

        if (error != null) {
            for (i in 0...failingIndex) {
                indexes[keys[i]].removeMany( docs );
            }

            throw error;
        }
    }

    public function updateIndexes(oldDoc:Item, newDoc:Item) {
         var failingIndex:Int = -1,
        error: Dynamic = null,
        keys = indexes.keyArray();

        for (i in 0...keys.length) {
            try {
                indexes[keys[i]].updateOne(oldDoc, newDoc);
            }
            catch (e: Dynamic) {
                failingIndex = i;
                error = e;
                break;
            }
        }

        if (error != null) {
            for (i in 0...failingIndex) {
                indexes[keys[i]].revertUpdate(oldDoc, newDoc);
            }

            throw error;
        }
    }

    public inline function freshQuery() {
        return Query.make(Store(this));
    }

    public function makeQuery(fn: Query<Item> -> Query<Item>):Query<Item> {
        return freshQuery().apply( fn );
    }

    public function getCandidates(check: Criterion<Item>):Array<Item> {
        var ncheck = q.check( check );
        return q.getSearchIndex(q.check( check ))
        .apply(function(idx) {
            return switch ( idx.filter ) {
                case ICNone: idx.index.getAll();
                case ICKey(key): idx.index.getByKey( key );
                case ICKeyList(keys): idx.index.getByKeys( keys );
                case ICKeyRange(min, max): idx.index.getBetweenBounds(min, max);
            }
        })
        .apply(function(docs: Array<Item>) {
           return docs
            .filter(function(item: Item):Bool {
               q.ctx.setDoc(cast item);
               return ncheck.eval( q.ctx );
           });
        });
    }

    public function find(?check: Criterion<Item>) {
        return makeQuery(function(query) {
            return if (check != null)
                query.where(q.check( check ))
                else query;
        }).result();
    }

    /**
      get all documents matched by [query]
     **/
    public function findAll(filter:Criterion<Item>, ?precompile:Bool):Array<Item> {
        return q.find(filter, precompile).getAllNative();
    }

    /**
      return the first item that matches [query]
     **/
    public function findOne(query:Criterion<Item>, ?precompile:Bool):Null<Item> {
        throw 'Not Implemented';
        //var res = cursor( query ).limit( 1 ).exec( precompile );
        //return switch res {
            //case null: null;
            //case _: res[0];
        //}
    }

    /**
      remove items that match the given Query
     **/
    public function remove(query:Criterion<Item>, multiple:Bool=false):Array<Item> {
        throw 'Not Implemented';
        //var q = query.filter;
        //var numRemoved:Int = 0,
        //removedDocs:Array<Item> = new Array();

        //for (d in getCandidates( q )) {
            //if (q.match(cast d) && (multiple || numRemoved == 0)) {
                //numRemoved++;
                //removedDocs.push( d );
                //removeOneFromIndexes( d );
            //}
        //}

        //_persist();

        //return removedDocs;
    }

    /**
      perform an update on [this] Store
      [=NOTE=]
      the current api for creating and defining Update<T> objects 
      is merely a placeholder, and will be replaced with a less verbose, more performant one soon
     **/
    public function update(fn:Update<Item>->Void, multiple:Bool=false) {
        throw 'Not Implemented';
    }

    @:noCompletion
    public function _overwrite(oldDoc:Item, newDoc:Item):Item {
        var idKey = Reflect.field(oldDoc, primaryKey);
        if (idKey == null)
            throw new Error();
        if (Reflect.hasField(newDoc, primaryKey) && !Arch.areThingsEqual(Reflect.field(newDoc, primaryKey), idKey))
            throw new Error('Item($newDoc) has extra field "$primaryKey"');

        Reflect.setField(newDoc, primaryKey, idKey);
        return insertOne( newDoc );
    }

/* === Computed Instance Fields === */

    public var primaryKey(get, never): String;
    inline function get_primaryKey():String return schema.primaryKey;

    // primary Index for [this] Store
    public var pid(get, never): Index<Any, Item>;
    private function get_pid():Index<Any, Item> return indexes[primaryKey];

/* === Instance Fields === */

    // Map of Indexes on [this] Store
    public var indexes(default, null): Map<String, Index<Any, Item>>;

    // Object-Model of type-information for [Item]
    public var schema(default, null): StructSchema;

    // name of primary index (defaults to "_id")
    //public var primaryKey(default, null): String;

    // options for [this] Store
    private var options(default, null): StoreOptions;

    // interface for 'next-generation' queries
    public var q: StoreQueryInterface<Item>;
}

typedef StoreOptions = {
    ?primary: EitherType<String, StoreIndexOptions>,
    ?indexes: Array<StoreIndexOptions>,
    ?schema: StructSchema
    //?inMemoryOnly: Bool,
    //?filename: String,
};

typedef StoreIndexOptions = {
    name: String,
    ?type: DataType,
    ?unique: Bool,
    ?sparse: Bool
};

enum StoreErrorCode<T> {
    EConstraintViolated;
    ECustom(msg: String);
}
