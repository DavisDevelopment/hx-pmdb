package pmdb.core;

import pm.Lazy;
import pm.Ref;
//import tannus.math.TMath as M;

import pmdb.ql.types.*;
import pmdb.ql.ts.DataType;
import pmdb.core.ds.AVLTree;
import pmdb.core.ds.*;
import pmdb.core.Comparator;
import pmdb.ql.ast.BoundingValue;

import haxe.ds.Either;
import haxe.ds.Option;
import hscript.Expr.Const;

using StringTools;
//using tannus.ds.StringUtils;
//using Slambda;
//using tannus.ds.ArrayTools;
//using tannus.ds.DictTools;
using pm.Strings;
using Lambda;
using pm.Arrays;
using pm.Maps;
using pm.Options;
using pm.Functions;
using pmdb.ql.ts.DataTypes;

@:access(pmdb.core.ds.AVLTree)
class Index<Key, Item> {
    /* Constructor Function */
    public function new(options: IndexOptions<Key, Item>):Void {
        this.options = options;

        init();
        reset();
    }

/* === Instance Methods === */

    private inline function pullOptions(o: IndexOptions<Key, Item>):Void {
        //
    }

    /**
      insert a single Item onto [this] Index
     **/
    public function insertOne(doc: Item):Void {
        var key:Key = _fn.get(cast doc, null);

        if (key == null && !sparse) {
            throw 'IndexError: $doc is missing "$fieldName" property';
        }
        
        try {
            tree.insert(key, doc);
        }
        catch (error: pm.Error) {
            if (error.name == 'IndexError') {
                @:privateAccess error.message = '("$fieldName") ' + error.message;
            }
            throw error;
        }
    }

    /**
      remove a single document from [this] Index
     **/
    public function removeOne(doc: Item) {
        //var key = getDocKey( doc );
        var key:Key = _fn.get(cast doc, null);
        if (key == null) {
            if ( sparse ) {
                return ;
            }
            else {
                throw 'IndexError';
            }
        } 

        tree.delete(key, doc);
    }

    /**
      updates a single document
     **/
    public function updateOne(oldDoc:Item, newDoc:Item) {
        // delete the document to be updated
        removeOne( oldDoc );

        try {
            // attempt to insert the replacement document
            insertOne( newDoc );
        }
        catch (e: Dynamic) {
            // if the attempt fails, reinsert the old document
            insertOne( oldDoc );
            // and rethrow the error
            throw e;
        }
    }

    /**
      insert an array of items on [this] Index
     **/
    public function insertMany(docs:Array<Item>):Void {
        try {
            for (i in 0...docs.length) {
                try {
                    insertOne(docs[i]);
                }
                catch (e: Dynamic) {
                    throw new IndexRollback(e, i);
                }
            }
        }
        catch (rollback: IndexRollback<Dynamic>) {
            for (i in 0...rollback.failingIndex) {
                removeOne(docs[i]);
            }

            throw rollback.error;
        }
        catch (error: Dynamic) {
            throw error;
        }
    }

    /**
      delete multiple items
     **/
    public function removeMany(docs: Array<Item>):Void {
        for (doc in docs) {
            removeOne( doc );
        }
    }

    /**
      handle an Array of updates
     **/
    public function updateMany(updates: Array<{oldDoc:Item, newDoc:Item}>) {
        var revert:Array<{oldDoc:Item, newDoc:Item}> = new Array();
        for (update in updates) {
            try {
                updateOne(update.oldDoc, update.newDoc);
                revert.push( update );
            }
            catch (e: Dynamic) {
                revertUpdates( revert );
                throw e;
            }
        }
        revert = [];
    }

    /**
      reverse (undo) a given list of updates
     **/
    function revertUpdates(updates: Array<{oldDoc:Item, newDoc:Item}>) {
        updates = updates.map(u -> {oldDoc: u.newDoc, newDoc: u.oldDoc});
        updateMany( updates );
    }

    /**
      reverse a singular 'update' operation
     **/
    public inline function revertUpdate(oldDoc:Item, newDoc:Item) {
        updateOne(newDoc, oldDoc);
    }

    /**
      revert an entire list of update-operations
     **/
    public function revertAllUpdates(updates: Array<{oldDoc:Item, newDoc:Item}>) {
        updateMany(updates.map(function(u) {
            return {
                oldDoc: u.newDoc,
                newDoc: u.oldDoc
            };
        }));
    }

    /**
      get the items stored under the given key
     **/
    public function getByKey(key: Key):Null<Array<Item>> {
        return tree.get( key );
    }

    /**
      get all items stored collectively under all given [keys]
     **/
    public function getByKeys(keys: Array<Key>):Array<Item> {
        var res = [];
        for (key in keys) {
            switch getByKey( key ) {
                case null:
                    continue;

                case items:
                    res = res.concat( items );
            }
        }
        return res;
    }

    /**
      get the values at the keys between [min] and [max]
      TODO:refactor implementation of AVLTree.betweenBounds
     **/
    @:deprecated('refactor implementation of AVLTree.betweenBounds')
    public function getBetweenBounds(?min:BoundingValue<Key>, ?max:BoundingValue<Key>):Array<Item> {
        //return (#if js cast inline #end tree.betweenBounds(#if js cast #end min, #if js cast #end max) : Array<Item>);
        return tree.betweenBounds(min, max);
    }

    public function getLt(v: Key):Array<Item> {
        return inline getBetweenBounds(null, Edge(v));
    }

    public function getLte(v: Key):Array<Item> {
        return inline getBetweenBounds(null, Inclusive(v));
    }

    public function getGt(v: Key):Array<Item> {
        return inline getBetweenBounds(Edge(v), null);
    }

    public function getGte(v: Key):Array<Item> {
        return inline getBetweenBounds(Inclusive(v), null);
    }

    /**
      obtain an Array of all Items stored on [this] Index
     **/
    public function getAll():Array<Item> {
        var ret = [];
        tree.executeOnEveryNode(function(node) {
            Utils.Arrays.append(ret, node.data);
        });
        return ret;
    }

    /**
      get the total number of documents stored in [this] Index
     **/
    public inline function size() {
        return inline tree.size();
    }

    /**
      perform basic initialization of [this] Index
     **/
    function init() {
        fieldName = options.fieldName;
        fieldType = options.fieldType != null ? options.fieldType : TScalar(TString);
        sparse = false;
        switch [options.sparse, fieldType] {
            case [null, TNull(t)]:
                fieldType = t;
                sparse = true;

            case [v, TNull(t)]:
                fieldType = t;
                sparse = v;

            case [v, _]:
                sparse = v;
        }

        if (_fn == null)
            _fn = DotPath.fromPathName(fieldName);

        pullOptions( options );
    }

    /**
      reset [this] Index's state
     **/
    function reset():Void {
        init_tree();
    }

    /**
      initialize [this]'s [tree] property
     **/
    function init_tree():Void {
        tree = null;

        var kc:Comparator<Key> = key_comparator();
        if ( sparse ) {
            kc = Comparator.makeNullable( kc );
        }

        _kc = kc;
        _ie = item_equator();

        tree = new FAVLTree({
            unique: options.unique,
            model: TreeModel.of(kc, _ie)
        });
    }

    /**
      get the 'Key' for the given Item
     **/
    public inline function getDocKey(doc: Item):Null<Key> {
        return _fn.get(cast doc, null);
    }

    /**
      creates and returns [this] Index's Key-Comparator
     **/
    public function key_comparator():Comparator<Key> {
        if (_kc == null) {
            _kc = cast fieldType.getTypedComparator();
        }
        return _kc;
    }

    /**
      creates and returns [this] Index's item equator
     **/
    public function item_equator():Equator<Item> {
        if (_ie == null) {
            _ie = cast Equator.anyEq();
        }

        return _ie;
    }

/* === Computed Instance Fields === */

    public var unique(get, never): Bool;
    inline function get_unique() return tree.unique;

/* === Instance Fields === */

    public var fieldName(default, null): String;
    public var fieldType(default, null): DataType;
    public var sparse(default, null): Bool;

    @:noCompletion
    public var tree(default, null): AVLTree<Key, Item>;

    public var options(default, null): IndexOptions<Key, Item>;

    var _fn: Null<DotPath>;
    var _kc: Null<Comparator<Key>>;
    var _ie: Null<Equator<Item>>;
}

typedef IndexOptions<Key, Item> = {
    fieldName: String,
    ?fieldType: DataType,
    ?keyComparator: Comparator<Key>,
    ?itemEquator: Equator<Item>,
    ?getItemKey: Item -> Key,
    ?unique: Bool,
    ?sparse: Bool
};

//@:structInit
class IndexRollback<Error> {
    public inline function new(e, i) {
        this.error = e;
        this.failingIndex = i;
    }
    public var error: Error;
    public var failingIndex: Int;
}

class IndexError<K, V> extends Error {
    /* Constructor Function */
    public function new(?type:IndexErrorCode<K, V>, ?msg, ?pos:haxe.PosInfos) {
        super(msg, pos);

        this.type = (type != null ? type : cast IndexErrorCode.AssertionFailed);
    }

    public var type(default, null): IndexErrorCode<K, V>;
}

enum IndexErrorCode<K, V> {
    AssertionFailed;
    UniqueConstraintViolated;
    MissingProperty(name: String);
    Custom(msg: String);
}
