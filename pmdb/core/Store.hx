package pmdb.core;

import tannus.ds.Anon;
import tannus.ds.Lazy;
import tannus.ds.Ref;
import tannus.math.TMath as M;

import pmdb.ql.types.*;
import pmdb.ql.types.DataType;
import pmdb.core.ds.AVLTree;
import pmdb.core.ds.*;

import haxe.ds.Either;
import haxe.extern.EitherType;
import haxe.ds.Option;
import haxe.PosInfos;

import haxe.macro.Expr;
import haxe.macro.Context;

import pmdb.core.Error;
import Slambda.fn;
import Std.is as isType;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.ds.DictTools;
using tannus.ds.MapTools;
using tannus.async.OptionTools;
using tannus.FunctionTools;
using pmdb.ql.types.DataTypes;

/**
  Store<Item> - stores a "table" of documents, indexed by their various keys
  based heavily on louischatriot's "nedb" [DataStore](https://github.com/louischatriot/nedb/blob/master/lib/datastore.js)
 **/
class Store<Item> {
    /* Constructor Function */
    public function new(options: StoreOptions):Void {
        this.options = options;
        indexes = new Map();

        _init_();
    }

/* === Internal Methods === */

    private function _init_() {
        _init_indices_();
    }

    private function _init_indices_():Void {
        /* == Primary Index == */
        this.primaryKey = '_id';

        // create options for the primary index
        var pi: StoreIndexOptions = {
            name: '_id',
            unique: true,
            sparse: false
        };

        // merge [pi] with the options provided to the constructor (if any)
        if (options.primary != null) {
            if (isType(options.primary, String)) {
                pi.name = cast options.primary;
            }
            else {
                pi = cast options.primary;
            }
        }

        // ensure that [pi]'s type is properly provided
        if (pi.type == null)
            pi.type = TAny;

        // ensure that [pi]'s options are valid for a primary key
        pi.unique = true;
        pi.sparse = false;
        primaryKey = pi.name;
        indexes[primaryKey] = buildIndex( pi );

        if (options.indexes != null) {
            for (idx in options.indexes) {
                ensureIndex( idx );
            }
        }
    }

    /**
      prepare the given Item for insertion into [this] Store
     **/
    private function prepareForInsertion(doc: Item):Item {
        var doc:Anon<Dynamic> = Anon.of(cast doc);

        return cast doc;
    }

    /**
      generate a new, universally unique id
     **/
    private function createNewId():String {
        return Arch.createNewIdString();
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

/* === Instance Methods === */

    /**
      get all data from [this] Store
     **/
    public function getAllData():Array<Item> {
        return pid.getAll();
    }

    /**
      insert one or more new documents into [this] Store
     **/
    public function insert(doc: N<Item>):Void {
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
            var preparedDocs = docs.map.fn(prepareForInsertion(_));
            addManyToIndexes( preparedDocs );
            _persist();
            return preparedDocs;
        }
    }

    /**
      insert
     **/
    private function _insert(doc: N<Item>) {
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
    private function _insertIntoCache(doc: N<Item>) {
        if (doc.isArray()) {
            insertMany(doc.asArray(false));
        }
        else {
            insertOne(doc.asItem(false));
        }
    }

    /**
      convenience method for creating a new Index
     **/
    public function addIndex<T>(name:String, ?type:DataType, ?unique:Bool, ?sparse:Bool):Index<T, Item> {
        var indexOptions:StoreIndexOptions = {
            name: name
        };
        if (type != null)
            indexOptions.type = type;
        if (unique != null)
            indexOptions.unique = unique;
        if (sparse != null)
            indexOptions.sparse = sparse;

        return cast ensureIndex( indexOptions );
    }

    /**
      ensure the existence of an Index on [this] Store
     **/
    public function ensureIndex(opts: StoreIndexOptions):Index<Any, Item> {
        // sanity checks
        if (opts.name.empty())
            throw new Error('cannot create and Index without a fieldName');

        if (indexes.exists( opts.name ))
            return indexes[opts.name];

        // build the index
        indexes[opts.name] = buildIndex( opts );

        // fill out the index
        indexes[opts.name].insertMany(getAllData());

        // return the created index
        return indexes[opts.name];
    }

    /**
      remove an Index from [this] Store
     **/
    public function removeIndex(fieldName: String) {
        indexes.remove( fieldName );
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
            }
            catch (e: Dynamic) {
                failingIndex = i;
                error = e;
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



/* === Computed Instance Fields === */

    // primary Index for [this] Store
    public var pid(get, never): Index<Any, Item>;
    private function get_pid():Index<Any, Item> return indexes[primaryKey];

/* === Instance Fields === */

    // Map of Indexes on [this] Store
    public var indexes(default, null): Map<String, Index<Any, Item>>;

    // name of primary index (defaults to "_id")
    public var primaryKey(default, null): String;

    // options for [this] Store
    private var options(default, null): StoreOptions;
}

typedef StoreOptions = {
    ?primary: EitherType<String, StoreIndexOptions>,
    ?indexes: Array<StoreIndexOptions>
    //?inMemoryOnly: Bool,
    //?filename: String,
};

typedef StoreIndexOptions = {
    name: String,
    ?type: DataType,
    ?unique: Bool,
    ?sparse: Bool
};

@:forward
abstract N<T> (EitherType<Array<T>, T>) from EitherType<Array<T>, T> to EitherType<Array<T>, T> {
    @:to
    public inline function toArray():Array<T> {
        return asArray(true);
    }

    @:to
    public inline function toItem():T {
        return asItem(true);
    }

    /**
      obtain reference to [this] as an Array<T>
     **/
    public function asArray(safe: Bool):Array<T> {
        if ( safe ) {
            if (isArray()) {
                return cast this;
            }
            else {
                throw new ValueError(Lazy.ofConst(this), Lazy.ofConst('$this is not an Array'));
            }
        }
        else {
            return cast this;
        }
    }

    /**
      obtain reference to [this] as T
     **/
    public function asItem(safe: Bool = false):T {
        if (!safe) {
            return cast this;
        }
        else {
            if (!isArray()) {
                return cast this;
            }
            else {
                throw new ValueError(Lazy.ofConst(this), Lazy.ofConst('$this is an Array'));
            }
        }
    }

    /**
      check if [this] is an Array
     **/
    public inline function isArray():Bool {
        return Arch.isArray( this );
    }
}

enum StoreErrorCode<T> {
    EConstraintViolated;
    ECustom(msg: String);
}
