package pmdb.core.query;

import pmdb.ql.types.*;
import pmdb.ql.ts.*;
import pmdb.ql.ts.DataType;
import pmdb.ql.ast.BoundingValue;
import pmdb.core.ds.AVLTree;
import pmdb.core.ds.*;
import pmdb.core.*;
import pmdb.core.query.IndexItemCaret;
import pmdb.core.Store;

import pmdb.ql.*;
import pmdb.ql.ast.*;
import pmdb.ql.ast.nodes.*;
import pmdb.ql.ast.QueryCompiler;
import pmdb.ql.QueryIndex;
import pmdb.ql.hsn.QlParser;
import pmdb.ql.ts.TypeSystemError;

import haxe.extern.EitherType;
import haxe.ds.Option;
import haxe.PosInfos;

import haxe.macro.Expr;
import haxe.macro.Context;

import pmdb.core.Assert.assert;
import pmdb.core.Error;
import Slambda.fn;
import Std.is as isType;
import pmdb.Macros.*;
import pmdb.Globals.*;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.async.OptionTools;
using tannus.ds.IteratorTools;
using tannus.FunctionTools;
using pmdb.ql.ast.Predicates;

class QueryCaret<Item> extends StdIndexItemCaret<Item> {
    /* Constructor Function */
    public function new(q: QueryIndex<Key, Item>):Void {
        super(cast q.index);
        
        queryIndex = q;
        simple = isSimpleKey( keyType );

        switch ( queryIndex.filter ) {
            case ICKeyList( keyList ):
                keyList.sort(function(a:Key, b:Key):Int {
                    return kc.compare(a, b);
                });

            default:
        }
    }

/* === Statics === */

    public static function create<Item>(q: QueryIndex<Key, Item>):QueryCaret<Item> {
        return switch ( q.filter ) {
            case IndexConstraint.ICNone:
                new QueryCaret( q );

            case IndexConstraint.ICKey( key ):
                new KeyQueryCaret(q, key);

            case IndexConstraint.ICKeyRange(null, null):
                throw new Invalid( q.filter );

            case IndexConstraint.ICKeyRange(min, null):
                new KeyFloorQueryCaret(q, min);

            case IndexConstraint.ICKeyRange(null, max):
                new KeyCeilingQueryCaret(q, max);

            case IndexConstraint.ICKeyRange(min, max):
                new KeyRangeQueryCaret(q, min, max);

            case IndexConstraint.ICKeyList( keys ):
                new KeyListQueryCaret(q, keys.copy());
        }
    }

/* === Methods === */

    override function validateItem(item: Item):Bool {
        return shouldYield( item );
    }

    public dynamic function shouldYield(item: Item):Bool {
        return superValidateItem( item );
    }

    function superValidateItem(item: Item):Bool {
        return super.validateItem( item );
    }

    /**
      TODO
     **/
    override function visitLeaf(node: Leaf<Item>) {
        return super.visitLeaf( node );
    }

    /**
      checks whether [value] is in [array] in whatever manner is deemed appropriate
     **/
    private inline function isKeyInArray(value:Key, array:Array<Key>):Bool {
        return simple ? isKeyInArraySimple(value, array) : isKeyInArrayComplex(value, array);
    }

    /**
      checks whether [value] is in [array] when a standard equality-check will suffice
     **/
    private inline function isKeyInArraySimple(value:Key, array:Array<Key>):Bool {
        return (array.indexOf(value) != -1);
    }

    /**
      checks whether [value] is in [array] using the Comparator<Key>
     **/
    private function isKeyInArrayComplex(value:Key, array:Array<Key>):Bool {
        for (elem in array) {
            if (value == elem || kc.eq(value, elem)) {
                return true;
            }
        }
        return false;
    }

    /**
      checks whether the given DataType can be compared via standard equality-checks, or if custom comparator is needed
     **/
    static function isSimpleKey(type: DataType):Bool {
        return switch type {
            case TAny|TMono(_): false;
            case TScalar(TBytes|TDate): false;
            case TScalar(_): true;
            case TArray(_)|TTuple(_): false;
            case TNull(type): isSimpleKey(type);
            case TUnion(ltype, rtype): isSimpleKey(ltype)&&isSimpleKey(rtype);
            case TAnon(_)|TClass(_)|TStruct(_): false;
        }
    }

/* === Properties === */

    public var kc(get, never): Comparator<Dynamic>;
    inline function get_kc():Comparator<Dynamic> return index.key_comparator();

    public var ie(get, never): Equator<Item>;
    inline function get_ie() return index.item_equator();

    public var keyType(get, never): DataType;
    inline function get_keyType():DataType return index.fieldType;

/* === Variables === */

    public var queryIndex(default, null): QueryIndex<Key, Item>;

    private var simple(default, null): Bool;
}

class KeyQueryCaret<Item> extends QueryCaret<Item> {
    public function new(q, key:Key) {
        super( q );
        this.key = key;
    }

    override function validateLeaf(node: Leaf<Item>):Bool {
        return (key == node.key || kc.eq(key, node.key));
    }

    override function visitLeaf(node: Leaf<Item>) {
        // if [key] < [node.key]
        if (kc.lt(key, node.key))
            // move left along tree
            left( node );

        // if [key] > [node.key]
        else if (kc.gt(key, node.key))
            // move right
            right( node );
    }

    var key(default, null): Key;
}

// A > B
class KeyFloorQueryCaret<Item> extends QueryCaret<Item> {
    public function new(q, min:BoundingValue<Key>) {
        super( q );

        this.min = min;
    }

    override function getFirstNode(tree: Tree<Item>):Leaf<Item> {
        var node = super.getFirstNode( tree );
        var min = minimumKey();

        while (node != null) {
            trace('${node.key} < $min');
            if (kc.lt(node.key, min)) {
                node = node.right;
            }
            else {
                break;
            }
        }

        return node;
    }

    override function validateLeaf(node: Leaf<Item>):Bool {
        return validateKey( node.key );
    }

    inline function minimumKey():Key {
        return switch min {
            case Edge(x), Inclusive(x): x;
        }
    }

    inline function validateKey(key: Key):Bool {
        return switch min {
            case BoundingValue.Edge(min):
                //kc.gt(key, min);
                kc.compare(key, min) > 0;

            case BoundingValue.Inclusive(min):
                //kc.gte(key, min);
                kc.compare(key, min) >= 0;
        }
    }

    var min(default, null): BoundingValue<Key>;
}

// A < B
class KeyCeilingQueryCaret<Item> extends QueryCaret<Item> {
    public function new(q, max:BoundingValue<Key>) {
        super( q );

        this.max = max;
    }

    override function getFirstNode(tree: Tree<Item>):Leaf<Item> {
        var node = super.getFirstNode( tree );
        var max = maximumKey();

        while (node != null) {
            if (kc.gt(node.key, max)) {
                node = node.left;
            }
            else {
                break;
            }
        }

        return node;
    }

    override function validateLeaf(node: Leaf<Item>):Bool {
        return validateKey( node.key );
    }

    inline function maximumKey():Key {
        return switch max {
            case Edge(x), Inclusive(x): x;
        }
    }

    function validateKey(key: Key):Bool {
        return switch max {
            case BoundingValue.Edge(max): kc.lt(key, max);
            case BoundingValue.Inclusive(max): kc.lte(key, max);
        }
    }

    var max(default, null): BoundingValue<Key>;
}

class KeyRangeQueryCaret<Item> extends QueryCaret<Item> {
    public function new(q, ?min:BoundingValue<Key>, ?max:BoundingValue<Key>) {
        super( q );

        this.min = min;
        this.max = max;
    }

    override function getFirstNode(tree: Tree<Item>):Leaf<Item> {
        var node = super.getFirstNode( tree );
        var min = minimumKey();

        while (node != null) {
            if (kc.lt(node.key, min)) {
                node = node.right;
            }
            else {
                break;
            }
        }

        return node;       
    }

    override function validateLeaf(node: Leaf<Item>):Bool {
        return validateKey( node.key );
    }

    override function visitLeaf(node: Leaf<Item>) {
        inline function test(n: Null<Leaf<Item>>) {
            return (n != null && validateKey( n.key ));
        }

        if (validateKey( node )) {
            if (node.left != null && validateKeyMin( node.left.key )) {
                left( node );
            }

            if (node.right != null && validateKeyMax( node.right.key )) {
                right( node );
            }
        }
    }

    inline function minimumKey():Key {
        return valueOfBv( min );
    }

    inline function maximumKey():Key {
        return valueOfBv( max );
    }

    static inline function valueOfBv<T>(v: BoundingValue<T>):T {
        return switch v {
            case Edge(v), Inclusive(v): v;
        }
    }

    inline function validateKey(key: Key) {
        return validateKeyMin(key) && validateKeyMax(key);
    }

    inline function validateKeyMin(key: Key):Bool {
        return switch min {
            case BoundingValue.Edge(min): kc.gt(key, min);
            case BoundingValue.Inclusive(min): kc.gte(key, min);
        }
    }

    inline function validateKeyMax(key: Key):Bool {
        return switch max {
            case BoundingValue.Edge(max): kc.lt(key, max);
            case BoundingValue.Inclusive(max): kc.lte(key, max);
        }
    }

    var min(default, null): BoundingValue<Key>;
    var max(default, null): BoundingValue<Key>;
}

class KeyListQueryCaret<Item> extends QueryCaret<Item> {
    public function new(q, keys:Array<Key>) {
        super( q );

        this.keys = keys;
        this.keys.sort(function(a:Key, b:Key):Int {
            return kc.compare(a, b);
        });
    }

    override function validateLeaf(node: Leaf<Item>):Bool {
        return validateKey( node.key );
    }

    inline function validateKey(key: Key):Bool {
        return isKeyInArray(key, keys);
    }

    var keys(default, null): Array<Key>;
}

typedef Key = Dynamic;
