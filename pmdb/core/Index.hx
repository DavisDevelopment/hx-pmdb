package pmdb.core;

import tannus.ds.Anon;
import tannus.ds.Lazy;
import tannus.ds.Ref;
import tannus.math.TMath as M;

import pmdb.ql.types.*;
import pmdb.ql.types.DotPath;
import pmdb.ql.types.DataType;
import pmdb.core.ds.AVLTree;
import pmdb.core.ds.*;
import pmdb.core.Comparator;

import haxe.ds.Either;
import haxe.ds.Option;
import hscript.Expr.Const;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
//using tannus.ds.ArrayTools;
using tannus.ds.DictTools;
using tannus.ds.MapTools;
using tannus.async.OptionTools;
using tannus.FunctionTools;
using pmdb.ql.types.DataTypes;

@:access(pmdb.core.ds.AVLTree)
class Index<Key, Item> {
    /* Constructor Function */
    public function new(options: IndexOptions) {
        this.options = options;
        init();
        reset();
    }

/* === Instance Methods === */

    /**
      insert a single Item onto [this] Index
     **/
    public function insertOne(doc: Item):Void {
        var key:Key = _fn.follow( doc );

        if (key == null && !sparse) {
            throw 'IndexError: Missing "$fieldName" property';
        }
        
        tree.insert(key, doc);
    }

    /**
      remove a single document from [this] Index
     **/
    public function removeOne(doc: Item) {
        //var key = getDocKey( doc );
        var key:Key = _fn.follow( doc );
        trace( doc );
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
    public function insertMany(docs: Array<Item>):Void {
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
     **/
    public function getBetweenBounds(?min:BoundingValue<Key>, ?max:BoundingValue<Key>):Array<Item> {
        return tree.betweenBounds(min, max);
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

            default:
                //
        }

        if (_fn == null)
            _fn = DotPath.parse( fieldName );
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
        if ( sparse )
            kc = Comparator.makeNullable( kc );
        var ie:Equator<Item> = item_equator();

        tree = new FAVLTree({
            unique: options.unique,
            model: TreeModel.of(kc, ie)
        });
    }

    public inline function getDocKey(doc: Item):Null<Key> {
        return _fn.follow( doc );
    }

    /**
      creates and returns [this] Index's Key-Comparator
     **/
    public function key_comparator():Comparator<Key> {
        return dt_comparator( fieldType );
    }

    /**
      creates and returns [this] Index's item equator
     **/
    public function item_equator():Equator<Item> {
        return cast Equator.any();
    }

    /**
      create and return a Comparator<T> from the given DataType
     **/
    static function dt_comparator<T>(type: DataType):Comparator<T> {
        return switch type {
            case TAny: Comparator.any();
            case TScalar(stype): switch stype {
                case TBoolean: cast Comparator.boolean();
                case TInteger: cast Comparator.int();
                case TDouble: cast Comparator.float();
                case TString: cast Comparator.string();
                case TDate: cast Comparator.date();
                case _: throw 'unex';
            }
            case TArray(item): cast Comparator.arrayComparator(dt_comparator(item));
            case _: throw 'unex';
        }
    }

/* === Computed Instance Fields === */

    public var unique(get, never): Bool;
    inline function get_unique() return tree.unique;

/* === Instance Fields === */

    public var fieldName(default, null): String;
    public var fieldType(default, null): DataType;
    public var sparse(default, null): Bool;

    private var tree(default, null): AVLTree<Key, Item>;
    private var options(default, null): IndexOptions;

    var _fn: Null<DotPath>;
}

typedef IndexOptions = {
    fieldName: String,
    ?fieldType: DataType,
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
