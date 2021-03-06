package pmdb.core;

import pm.datetime.DateTimeUtc;
import pmdb.ql.types.*;
import pmdb.ql.ts.*;
import pmdb.ql.ts.DataType;
import pmdb.core.ds.AVLTree;
import pmdb.core.ds.Lazy;
import pmdb.ql.ast.BoundingValue;
import pmdb.core.ds.*;
import pmdb.core.*;
import pmdb.core.query.Criterion;
import pmdb.core.query.Mutation;
import pmdb.ql.QueryIndex;
import pmdb.core.query.StoreQueryInterface;
import pmdb.core.query.FindCursor;
import pmdb.core.query.UpdateCursor;
import pmdb.core.query.UpdateHandle;

import pmdb.core.StructSchema;
import pmdb.core.schema.SchemaField;
import pmdb.core.schema.FieldFlag;
import pmdb.core.schema.Types.IndexType;
import pmdb.core.schema.Types.IndexAlgo;

import pmdb.storage.Persistence;
import pmdb.storage.Storage;
import pmdb.async.Executor;

import pm.async.*;
import pm.datetime.DateTime;

import haxe.ds.Either;
import haxe.extern.EitherType;
import haxe.ds.Option;
import haxe.PosInfos;

import haxe.macro.Expr;
import haxe.macro.Context;

import pmdb.core.Error;
import pm.Functions.fn;
import Std.is as isType;
import pm.Assert.assert;

using pmdb.core.Arch;
using StringTools;
using pm.Strings;
using Lambda;
using pm.Arrays;
using pm.Maps;
using pmdb.core.ds.tools.Options;
using pm.Functions;
using pmdb.ql.ts.DataTypes;

/**
  Store<Item> - stores a "table" of documents, indexed by their various keys
  based heavily on louischatriot's "nedb" [DataStore](https://github.com/louischatriot/nedb/blob/master/lib/datastore.js)
 **/
class Store<Item> extends Emitter<String, Dynamic> {
    /* Constructor Function */
    public function new(options: StoreOptions):Void {
        super();
        this._signals = new haxe.ds.StringMap();

        this.options = options;

        indexes = new Map();
        schema = null;
        persistence = null;

        if (options.schema != null) {
            schema = options.schema;
        }

        // - default schema
        if (schema == null) {
            schema = new StructSchema();
            schema.addField(DKEY, DataType.TAny, [Primary]);
            schema.putIndex(IndexType.Simple(DKEY));
        }

        if (options.persistence != null) {
            persistence = cast options.persistence;
        }

        if (persistence == null) {
            persistence = new Persistence({
                filename: options.filename,
                storage: options.storage
            });
        }
        if (options.storage != null && options.persistence != null) {
            @:privateAccess persistence.storage = options.storage;
        }

        if (options.executor != null) {
            executor = options.executor;
        }

        if (executor == null) {
            executor = new Executor();
        }

        _init_();

        q = new StoreQueryInterface( this );

        /*
         == Declare Store Events
        */
        addEvent('persistent');
        addEvent('close');
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
        inline _init_id_();

        assert(schema != null, new Error('Schema must be provided'));


        final allowIndexingOnDynamicFields = true;
        for (info in schema.indexes) {
            
            if (allowIndexingOnDynamicFields || schema.hasField( info.name )) {
                addSimpleIndex( info.name );
            }
        }
    }

    /**
      initialize the primary-index
     **/
    private function _init_id_() {
        ensureIndex({
            name: DKEY,
            type: DataType.TAny,
            unique: true,
            sparse: false
        });
    }

    @:keep
    function toString():String {
        return Type.getClassName(Type.getClass(this)).afterLast('.').append("(").append(
            if (Reflect.hasField(this, 'name')) '"'+Reflect.field(this, 'name')+'"'
            else '#$_id'
        ).append(')');
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

    /**
      -
     **/
    private function _persist() {
        //TODO
        // this method is a placeholder for an actual persistence implementation
    }

    private function _execKey():String {
        return 'store';
    }

    private function _updatePromise(promise: Promise<Store<Item>>):Promise<Store<Item>> {
        return promise;
    }

    /**
      persist [this] Store to a data file
     **/
    public function _compact():Promise<Store<Item>> {
        var fp = (() -> persistence.persistCachedDataStore( this ));
        return _updatePromise(new Promise<Store<Item>>(function(accept, reject) {
            executor.exec(_execKey(), fp, function(prom: Promise<Store<Item>>) {
                prom.then(cast accept, cast reject);
            });
        }));
    }

    /**
      load [this] Store from a data file
     **/
    private var _loadcc:Int=0;
    public function _load(?pos: haxe.PosInfos):Promise<Store<Item>> {
        trace('_load called from ${pos.fileName}:${pos.lineNumber}');

        inline function isStaleForSomeReason(promise: Promise<Store<Item>>):Bool {
            return false;
        }


        var output:Promise<Store<Item>> = Promise.async(function(done) {
            #if hxnodejs
            if (_loadcc != 0) {
                Console.printlnFormatted('<#F00><bg#FFF>You did a bad!<//>');
            }
            _loadcc++;
            #end

            var hasBeenLoadedPromise = this.persistence.loadDataStore(this).failAfter(1000);
            hasBeenLoadedPromise.then(function(self: Store<Item>) {
                #if !notrace
                Console.debug({
                    loaded: self.size(),
                    loadedAt: (DateTime.now().toString())
                });
                #end
            });
            return hasBeenLoadedPromise.handle(done);
        });

        this._loadInProgress = output;
        
        return output.failAfter(1200);
    }

    public function schedule<T>(fn:Store<Item>->T):Promise<T> {
        return new Promise<T>(function(accept, reject) {
            var res:Null<T> = null;
            executor.exec(_execKey(), function() {
                return Promise.resolve(res = fn( this ));
            })
            .map(x -> res)
            .then(x -> accept( x ), x -> reject( x ));
        });
    }

    public function lockio(?force: Int):Int {
        if (force == null) {
            return ++this.ioLock;
        }
        else {
            return this.ioLock = force;
        }
    }

    public function unlockio():Int {
        return --this.ioLock;
    }

    private function _syncCacheWithSchema() {
        //
    }

    /**
      called when a new field is added to the schema, on an existing Store instance
     **/
    private function _fieldAdded(field: SchemaField) {
        //_eachRow(function(row: Item) {
            
        //})
    }

    private function _fieldUpdated(oldField:SchemaField, newField:SchemaField) {
        //TODO resolve changes
    }

    private function _fieldDropped(field: SchemaField) {
        //
    }

    /**
      iterate over all rows
     **/
    private inline function _eachRow(fn: Item -> Void) {
        inline pid.getAll().iter( fn );
    }

/* === Instance Methods === */

    /**
      get all data from [this] Store
     **/
    public function getAllData():Array<Item> {
        trace(primaryKey);
        if (pid == null) {
            Sys.exit(0);
        }
        return pid.getAll();
    }

    /**
      get the total number of documents stored in [this] Store
     **/
    public function size():Int {
        if (pid != null) {
            return pid.size();
        }
        else {
            return 0;
        }
    }

    /**
      dump all documents and reset the index registry
     **/
    public function resetIndexes():Void {
        indexes = new Map();
        inline _init_id_();
    }

    public function reset():Void {
        inline resetIndexes();
    }

    /**
      gg (bruh)
     **/

    /**
      insert one or more new documents into [this] Store
      @return the versions
     **/
    public function insert(doc:OneOrMany<Item>, safe:Bool=false):Bool {
        if (!safe) {
            return !_insert( doc ).empty();
            // return true;
        }
        else {
            try {
                return !_insert(doc).empty();
                // return true;
            }
            catch (error: pm.Error) {
				if (error.message == 'IndexError: Unique-constraint violated') {
                    return false;
                }
                else {
                    throw error;
                }
                return false;
            }
        }
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
    public function insertMany(docs:Array<Item>, allowPartial:Bool=false, safe:Bool=false):Array<Item> {
        if ( allowPartial ) {
            var failed = [];
            for (doc in docs) {
                try {
                    var preparedDoc = prepareForInsertion( doc );
                    addOneToIndexes( preparedDoc );
                }
                // catch (err: pm.Error) {
                //     if (safe && err.message == 'IndexError: Unique-constraint violated') {

                //     }
                // }
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
            var insertedDocs = addManyToIndexes(preparedDocs, safe);
            
            // trace(insertedDocs);
            _persist();

            return insertedDocs;
        }
    }

    /**
      insert
     **/
    private function _insert(doc: OneOrMany<Item>):Array<Item> {
        try {
            var inserted:Array<Item> = _insertIntoCache(doc).asMany();
            
            if ( !ioLocked ) {
                // Console.printlnFormatted('<#F00>[INFO]</>scheduling .persistNewState');
                executor.exec(_execKey(), function() {
					return persistence.persistNewState((cast (inserted : Array<Dynamic>) : Array<pmdb.core.Object.Doc>));
                });
            }
            // Console.examine(doc, ioLocked);

            return inserted;
        }
        catch (err: Dynamic) {
            throw err;
        }
    }

    /**
      insert the given value(s) into [this] DataStore
     **/
    private function _insertIntoCache(doc: OneOrMany<Item>):OneOrMany<Item> {
        var output:OneOrMany<Item>;
        if (doc.isMany()) {
            output = insertMany(doc);
        }
        else {
            output = insertOne(doc.asOne());
        }
        return output;
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
        var prev:SchemaField = schema.field( name );

        var curr:SchemaField = schema.addField(name, type, flags);

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
    public function addSimpleIndex<T>(fieldName: EitherType<String, SchemaField>):Index<T, Item> {
        var field = (fieldName is SchemaField) ? (fieldName : SchemaField) : schema.field(cast fieldName);
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
      @returns the Items that were successfully inserted into the indexes
     **/
    public function addManyToIndexes(docs: Array<Item>, safe:Bool=false):Array<Item> {
        var failingIndex:Int = -1,
        error: Dynamic = null,
        keys = indexes.keyArray(),
        inserted = new Array();

        var failedDocs:Map<Int, Bool> = new Map();
        
        for (i in 0...keys.length) {
            var wasInserted = false;
            if (safe == true) {
                var failingDocIndex:Int = -1;

                for (j in 0...docs.length) {
                    if (failedDocs.exists(j) && failedDocs[j]) continue;
                    try {
                        indexes[keys[i]].insertOne(docs[j]);
                        wasInserted = true;
                    }
                    catch (err: pm.Error) {
						if (err.message == 'IndexError: Unique-constraint violated') {
                            wasInserted = false;
                            failedDocs[j] = true;
                        }
                        else {
                            failingDocIndex = j;
                            error = err;
                            break;
                        }
                    }
                    catch (err: Dynamic) {
                        failingDocIndex = j;
                        error = err;
                        break;
                    }

                }

                if (failingDocIndex != -1 && error != null) {
                    for (j in 0...failingDocIndex) {
                        indexes[keys[i]].removeOne(docs[j]);
                    }
                    failingIndex = i;
                    break;
                }
            }
            else {
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
        }

        if (error == null) {
            for (i in 0...docs.length) {
                if (!failedDocs[i]) {
                    inserted.push(docs[i]);
                }
            }
        }

        if (error != null) {
            for (i in 0...failingIndex) {
                indexes[keys[i]].removeMany( docs );
            }

            throw error;
        }

        return inserted;
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

    public function pluralUpdateIndexes(updates: Array<{pre:Item, post:Item}>) {
        var keys = indexes.keyArray();
        var failingIndex:Int = -1;
        var error: Dynamic = null;

        for (ui in 0...updates.length) {
            var oldDoc = updates[ui].pre,
                newDoc = updates[ui].post;

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

                failingIndex = ui;
                break;
            }
        }

        if (error != null) {
            //var didNotFail = updates.slice(0, failingIndex);
            //var swappedUpdates = didNotFail.map(u -> {pre:u.post, post:u.pre});
            //pluralUpdateIndexes( swappedUpdates );
            for (i in 0...failingIndex) {
                updateIndexes(updates[i].post, updates[i].pre);
            }

            throw error;
        }
    }

    /**
      delete an Item from `this` Store
     **/
    public function del(doc: Item):Bool {
        removeOneFromIndexes( doc );
        return true;
    }

    public function exists(a:Dynamic, ?b:Dynamic):Bool {
        if (b == null) {
            b = a;
            a = primaryKey;
        }
        return _exists(a, b);
    }

    function _exists(path:String, value:Dynamic):Bool {
        if (indexes.exists( path )) {
            var idx = index(path);
            var node = idx.getByKey(value);
            return !node.empty();
        }
        else {
            return !pid.getAll().filter(function(item: Item) {
                return Arch.getDotValue(item.asObject(), path).isEqualTo(value);
            }).empty();
        }

        return false;
    }

    /**
      fast single-field match lookup
     **/
    public function get(a:Dynamic, ?b:Dynamic):Null<Item> {
        if (b == null) {
            b = a;
            a = primaryKey;
        }
        return _get(a, b);
    }

    function _get(path:String, value:Dynamic):Null<Item> {
        if (indexes.exists( path )) {
            var idx = index( path );
            var bk = idx.getByKey(value);
            return if (bk != null) bk[0] else null;
        }
        else {
            return pid.getAll().find(function(item: Item) {
                return Arch.getDotValue(item.asObject(), path).isEqualTo( value );
            });
        }
    }

    // public inline function freshQuery() {
    //     return Query.make(Store(this));
    // }

    // public function makeQuery(fn: Query<Item> -> Query<Item>):Query<Item> {
    //     return freshQuery().apply( fn );
    // }

    /**
      get a subset of rows chosen based on constraints in [check]
     **/
    public function getCandidates(index: Null<QueryIndex<Any, Item>>):Array<Item> {
        if (index == null)
            return getAllData();
        return switch ( index.filter ) {
            case ICNone: index.index.getAll();
            case ICKey(key): index.index.getByKey( key );
            case ICKeyList(keys): index.index.getByKeys( keys );
            case ICKeyRange(min, max): index.index.getBetweenBounds(min, max);
        }
    }

    public function withValues(params: Array<Dynamic>):Store<Item> {
        q.ctx.parameters = params.copy();        
        return this;
    }

    public function explain(qs: String) {
        var expr = (@:privateAccess q.compileStringToPredicate( qs ));
        var a = expr.getTraversalIndex( indexes );
        var b = q.planSearch(q.check(expr)).index.get();
        trace('$a == $b');
        assert(Arch.areThingsEqual(a, b), 'neq!');
    }

    /**
      open and return a Cursor<Item> object for use in FIND operation
     **/
    public function find(?check:Criterion<Item>, ?precompile:Bool):FindCursor<Item> {
        return q.find(check != null ? check : cast Criterion.noop(), precompile);
    }

    /**
      get all documents matched by [query]
     **/
    public function findAll(filter:Criterion<Item>, ?precompile:Bool):Array<Item> {
        return q.find(filter, precompile).exec();
    }

    /**
      return the first item that matches [query]
     **/
    public function findOne(query:Criterion<Item>, ?precompile:Bool):Null<Item> {
        //throw 'Not Implemented';
        return q.findOne(query, precompile);
    }

    /**
      remove items that match the given Query
     **/
    public function remove(query:Criterion<Item>, multiple:Bool=false):Array<Item> {
        final cs = find( query );
        var nRemoved = 0, removedDocs = [];

        cs.forEach(function(item: Item) {
            nRemoved++;
            removedDocs.push( item );
            removeOneFromIndexes( item );

            if ( !multiple )
                return false;
            return true;
        });

        if ( !ioLocked ) {
            executor.exec(_execKey(), function() {
                return persistence.persistNewState(removedDocs.map(function(item) {
                    Reflect.setField(item, "$$deleted", true);
                    return item.asObject();
                }));
            });
        }

        return removedDocs;
    }

    public function count(query: Criterion<Item>):Int {
        var n = 0;
        find(query).forEach(function(x) {
            ++n;
            return null;
        });
        return n;
    }

    /**
      perform an update on [this] Store
      [=NOTE=]
      the current api for creating and defining Update<T> objects 
      is merely a placeholder, and will be replaced with a less verbose, more performant one soon
     **/
    public function update(what:Mutation<Item>, ?where:Criterion<Item>, ?options:{?precompile:Bool, ?multiple:Bool, ?insert:Bool}):UpdateHandle<Item> {
        // build [options]
        if (options == null)
            options = {};
        if (options.precompile == null)
            options.precompile = false;
        if (options.multiple == null)
            options.multiple = true;
        if (options.insert == null)
            options.insert = false;

        // execute the update
        var cursor:UpdateCursor<Item> = q.update(what, where, options.precompile);
        cursor.multiple( options.multiple );
        cursor.insert( options.insert );
        var logs = cursor.exec();
        var handle = new UpdateHandle(this, logs);

        // persist changes to the data
        if ( !ioLocked ) {
            executor.exec(_execKey(), function() {
                return persistence.persistNewState(logs.map(u -> (u.post : Dynamic)));
            });
        }

        return handle;
    }

    /**
      overwrite an existing document in [this] `Store<?>`
     **/
    public function replaceOne(p1:Item, ?p2:Item) {
        var oldDoc:Item, newDoc:Item;
        switch [p1, p2] {
            case [a, null]:
                newDoc = a;
                oldDoc = get(Reflect.field(newDoc, primaryKey));

            case [a, b]:
                oldDoc = a;
                newDoc = b;
        }

        var uid = Reflect.field(oldDoc, primaryKey);
        Reflect.setField(newDoc, primaryKey, uid);
        updateIndexes(oldDoc, newDoc);
        
        if ( !ioLocked ) {
            executor.exec(_execKey(), function() {
                return persistence.persistNewState([cast newDoc]);
            });
        }

        return {
            pre: oldDoc,
            post: newDoc
        };
    }

    /**
      overwrites an `Array` of existing documents
     **/
    public function replaceMany(docs: Array<Item>) {
        var failingIndex:Int = -1, exception:Dynamic = null;
        var completed = [];
        lockio();
        for (idx in 0...docs.length) {
            try {
                var log = inline replaceOne(docs[idx]);
                completed.push( log );
            }
            catch (err: Dynamic) {
                failingIndex = idx;
                exception = err;
                break;
            }
        }
        unlockio();
        if (exception != null && failingIndex != -1) {
            // rollback
            for (re in completed) {
                replaceOne(re.post, re.pre);
            }
            throw exception;
        }
        else {
            if (!ioLocked) {
                executor.exec(_execKey(), function() {
                    return persistence.persistNewState(cast completed.map(x -> x.post));
                });
            }
            return completed;
        }
        throw 'wtf';
    }

    @:noCompletion
    public function _overwrite(oldDoc:Item, newDoc:Item) {
        var idKey = idField.extract( oldDoc );
        if (idField.access.has(cast newDoc) && idField.access.eq(idField.extract(newDoc), idKey)) {
            throw new Error('Cannot change primary key');
        }

        idField.access.set(cast newDoc, idKey, true);
        
        //newDoc = insertOne( newDoc );
        //return newDoc;
        updateIndexes(oldDoc, newDoc);
    }

/* === Computed Instance Fields === */

    public var primaryKey(get, never): String;
    inline function get_primaryKey():String return schema.primaryKey;

    // primary Index for [this] Store
    public var pid(get, never): Index<Any, Item>;
    private function get_pid():Index<Any, Item> return indexes[primaryKey];

    // Id (primary key) property reference
    public var idField(get, never): SchemaField;
    private function get_idField() return schema.field( primaryKey );

    public var ioLocked(get, never): Bool;
    private function get_ioLocked() return ioLock > 0;

/* === Instance Fields === */

    public final _id:Int = pm.HashKey.next();

    // Map of Indexes on [this] Store
    public var indexes(default, null): Map<String, Index<Any, Item>>;

    // Object-Model of type-information for [Item]
    public var schema(default, null): StructSchema;

    // object used to persist [this] Store
    public var persistence(default, null): Persistence<Item>;

    // object used to schedule async tasks
    public var executor(default, null): Executor;

    //public var inMemoryOnly(default, null): Bool;
    //public var filename(default, null): String;

    // name of primary index (defaults to "_id")
    //public var primaryKey(default, null): String;

    // options for [this] Store
    private var options(default, null): StoreOptions;

    // interface for 'next-generation' queries
    public var q: StoreQueryInterface<Item>;

    // numeric counter for io locks
    @:noCompletion
    public var ioLock(default, null): Int = 0;
    @:noCompletion
    public var isLoaded(default, null):Bool = false;
    @:noCompletion
    public var _loadInProgress(default, null):Null<Promise<Store<Item>>> = null;
}

typedef StoreOptions = {
    ?primary: EitherType<String, StoreIndexOptions>,
    ?indexes: Array<StoreIndexOptions>,
    ?schema: StructSchema,
    ?inMemoryOnly: Bool,
    ?filename: String,
    ?persistence: Persistence<Any>,
    ?executor: Executor,
    ?storage: Storage
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

typedef Id<T> = Dynamic;
