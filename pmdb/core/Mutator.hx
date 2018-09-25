package pmdb.core;

import tannus.ds.Anon;
import tannus.ds.Lazy;
import tannus.ds.Ref;
import tannus.math.TMath as M;

import pmdb.ql.types.*;
import pmdb.ql.ts.DataType;
import pmdb.core.ds.AVLTree;
import pmdb.core.ds.*;
import pmdb.core.Cursor;
import pmdb.core.QueryFilter;
import pmdb.core.Alter;

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

/**
  abstract type which handles individual changes to be made to the documents in a table in an object-oriented way
 **/
@:forward
abstract Mutator<Item, R> (MutatorObject<Item, R>) from MutatorObject<Item, R> to MutatorObject<Item, R> {

    /**
      append [other] Mutator to the current one ([this]), and return a merged Mutator from both
     **/
    public function append(other: Mutator<Item, R>): Mutator<Item, R> {
        return new JoinMutator(this, other);
    }

/* === Factory Methods === */

    public static function passThrough<T>():Mutator<T, Dynamic> {
        return new PassThroughMutator();
    }

    /**
      property assignment
     **/
    public static function assign<T, O>(fieldName:String, val:T):Mutator<O, T> {
        return new AssignMutator<O, T>(fieldName, val);
    }

    /**
      property deletion
     **/
    public static function remove<T, O>(name:String, val:T):Mutator<O, T> {
        return new DeleteMutator(name, val);
    }

    /**
      addition of new values to arrays
     **/
    public static function push<T, O>(name:String, val:T):Mutator<O, T> {
        return new PushMutator(name, val);
    }

    /**
      addition of value to array
      IF not already present in the array
     **/
    public static function addToSet<T, O>(name:String, val:T):Mutator<O, T> {
        return new AddToSetMutator(name, val);
    }

    /**
      removal of all instances of [val] from an array
     **/
    public static function pull<T, O>(name:String, val:T):Mutator<O, T> {
        return new PullMutator(name, val);
    }

    /**
      removal of the first or last element in an array
     **/
    public static function pop<O>(name:String, val:Int):Mutator<O, Int> {
        return new PopMutator(name, val);
    }

    /**
      join any number of Mutators together, end-to-end and return a single Mutator that will apply all of them
     **/
    public static function join<T, O>(mutators: Array<Mutator<T, O>>):Mutator<T, O> {
        return mutators.compose((a:Mutator<T,O>, b:Mutator<T,O>) -> (a.append(b)), x -> x);
    }

    /**
      convert the given Update-Token into a Mutator-node
     **/
    @:allow(pmdb.core.Alter)
    private static function compileToken<O>(token: UpdTok):Mutator<O, Dynamic> {
        return
        (switch token.type {
            case "$set": assign;
            case "$unset": remove;
            case "$push": push;
            case "$pull": pull;
            case "$pop": cast pop;
            case "$addToSet": cast addToSet;

            case _:
                throw new Error('Invalid update-token ${token.type}');
        })(token.fieldName, token.value);
    }
}

interface MutatorObject<Item, Operand> {
    //var fieldName(default, null): String;
    //var value(default, null): Operand;

    function withStore(store: Store<Item>):Mutator<Item, Operand>;
    function apply(item: Item):Void;
    function finalApply(item: Item):Void;
}

class JoinMutator<T, V> implements MutatorObject<T, V> {
    /* Constructor Function */
    public function new(a, b) {
        this.a = a;
        this.b = b;
    }

    public function apply(d: T) {
        a.apply( d );
        b.apply( d );
    }

    public function finalApply(d: T) {
        a.finalApply( d );
        b.finalApply( d );
    }

    public function withStore(store: Store<T>):Mutator<T, V> {
        a.withStore( store );
        b.withStore( store );
        return this;
    }

    public var a(default, null): Mutator<T, V>;
    public var b(default, null): Mutator<T, V>;
}

class BaseMutator<Item, Operand> implements MutatorObject<Item, Operand> {
    /* Constructor Function */
    public function new(k, v) {
        //super(k, v);
        this.fieldName = k;
        this.value = v;

        this.fieldNameParts = fieldName.split('.');
        this.store = null;
    }

/* === Instance Methods === */

    /**
      atomic-level method that handles the actual changes made to the document
     **/
    public function finalApply(doc: Item) {
        throw new NotImplementedError();
    }

    public function withStore(store: Store<Item>):Mutator<Item, Operand> {
        this.store = store;
        return this;
    }

    /**
      apply [this] Mutator to the given document
     **/
    public function apply(doc: Item) {
        _apply(doc, fieldNameParts);
    }

    /**
      handle the recursive descent along the provided dot-path, 
      to ensure that [finalApply] is only invoked on the final step
     **/
    private function _apply(doc:Item, path:Array<String>) {
        if (path.length == 1) {
            finalApply( doc );
        }
        else {
            if (!Reflect.hasField(doc, path[0])) {
                missingField(doc, path[0]);
            }

            _apply(doc, path.slice(1));
        }
    }

    /**
      handle missing field
     **/
    private function missingField(doc:Item, name:String) {
        // the default behavior is to just create an empty object
        Reflect.setField(doc, name, {});
    }

    private function index<T>(name: String):Null<Index<Any, T>> {
        return
            if (store == null) null;
            else cast store.index(fieldName);
    }

    @:noCompletion
    public function _list<T>(d:Item, fn:Array<T>->Void) {
        if (!Reflect.hasField(d, fieldName))
            Reflect.setField(d, fieldName, new Array());

        var arr:Array<T> = cast Reflect.field(d, fieldName);
        if (!Arch.isArray( arr ))
            throw new Error('non-array');

        return arr;
    }

/* === Instance Fields === */

    public var fieldName(default, null): String;
    public var value(default, null): Operand;

    private var store(default, null): Null<Store<Item>>;
    private var fieldNameParts(default, null): Array<String>;
}

class AssignMutator<Item, Val> extends BaseMutator<Item, Val> {
    override function finalApply(doc: Item) {
        Reflect.setField(doc, fieldName, value);
    }
}

class DeleteMutator<Item, Val> extends BaseMutator<Item, Val> {
    override function finalApply(doc: Item) {
        Reflect.deleteField(doc, fieldName);
    }
}

class CompEqMutator<I, V> extends BaseMutator<I, V> {
    private var kcomp(default, null): Null<Comparator<V>>;
    private var veq(default, null): Null<Equator<V>>;

    override function apply(doc: I) {
        if (kcomp == null) {
            kcomp = switch index(fieldName) {
                case null: cast Comparator.cany();
                case i: cast i.key_comparator();
            }
        }

        if (veq == null) {
            veq = switch index(fieldName) {
                case null: cast Equator.any();
                case i: cast i.item_equator();
            }
        }

        super.apply( doc );
    }
}

class AddToSetMutator<Item, Val> extends CompEqMutator<Item, Val> {
    override function finalApply(doc: Item) {
        _list(doc, function(arr) {
            var add = true;
            for (item in arr) {
                if (kcomp.compare(item, value) == 0) {
                    add = false;
                }
            }
            if ( add ) {
                arr.push( value );
            }
        });
    }
}

class PushMutator<Item, Val> extends BaseMutator<Item, Val> {
    override function finalApply(doc: Item) {
        _list(doc, function(arr) {
            arr.push( value );
        });
    }
}

class PopMutator<I> extends BaseMutator<I, Int> {
    override function finalApply(doc: I) {
        _list(doc, function(arr) {
            if (value == 0) {
                return ;
            }
            else if (value > 0) {
                //o[field] = arr.slice(0, arr.length - 1);
                Reflect.setField(doc, fieldName, arr.slice(0, arr.length - 1));
            }
            else {
                Reflect.setField(doc, fieldName, arr.slice(1));
            }
        });
    }
}

class PullMutator<Item, Val> extends CompEqMutator<Item, Val> {
    override function finalApply(doc: Item) {
        _list(doc, function(arr: Array<Val>) {
            var i = (arr.length - 1);
            while (i >= 0) {
                if (veq.equals(arr[i], value)) {
                    arr.splice(i, 1);
                }

                --i;
            }

            trace('Aww, sha');
        });
    }
}

class PassThroughMutator<Doc> implements MutatorObject<Doc, Dynamic> {
    /* Constructor Function */
    public function new() { }

    public function withStore(store: Store<Doc>):Mutator<Doc, Dynamic> return this;

    public function apply(item: Doc):Void { }

    public function finalApply(item: Doc):Void { }
}
