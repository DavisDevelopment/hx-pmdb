package pmdb.core.query;

import pm.Lazy;

import pmdb.ql.types.*;
import pmdb.ql.ts.*;
import pmdb.ql.ts.DataType;
import pmdb.core.ds.AVLTree.AVLTreeNode as Leaf;
import pmdb.core.ds.LazyItr;
import pmdb.core.ds.map.Hash;
import pmdb.core.query.IndexItemCaret;
import pmdb.core.Store;
import pmdb.core.query.Value;

import pmdb.ql.*;
import pmdb.ql.ast.*;
import pmdb.ql.ast.nodes.*;
import pmdb.ql.ast.ASTError;
import pmdb.ql.ts.TypeSystemError;
import pmdb.ql.ast.QueryCompiler;
import pmdb.ql.QueryIndex;
import pmdb.ql.hsn.QlParser;
import pmdb.core.Error;

import haxe.extern.EitherType;
import haxe.ds.Option;
import haxe.PosInfos;

import pmdb.Macros.*;
import pmdb.Globals.*;
import pm.Functions.fn;
import Std.is as isType;
import pmdb.core.Assert.assert;

using StringTools;
using pm.Strings;
using pm.Arrays;
using pm.Functions;
using pm.Options;
using pmdb.ql.ast.Predicates;

/**
  TODO: optimize performance for FindCursor<Item> instances where [check] is unspecified
 **/
@:access(pmdb.core.query.StoreQueryInterface)
class FindCursor<Item> extends QueryCursor<Item, Array<Item>> implements ICursor<Array<Item>> {
    public function new(store, ?crit:Criterion<Item>, compile = false, noInit = false) {
        super( store );

        if (crit == null)
            crit = new pmdb.ql.ast.nodes.NoCheck();

        this.criterion = crit;
        this.checkNode = compileCriterion( criterion );

        this._compile = compile;
        this._output = null;

        if ( !noInit ) {
            init();
        }
    }

/* === Methods === */

    override function onIndexItemCaret(caret: IndexItemCaret<Item>) {
        super.onIndexItemCaret( caret );

        // if runtime compilation is enabled
        if ( _compile ) {
            _filterc = checkNode.compile();
            this.predicate = function(context, item:Item) {
                return _filterc(context.setDoc(item.asObject()));
            }
        }
    }

    /**
      "execute" the FIND operation represented by [this]
     **/
    override function exec():Array<Item> {
        if (_output == null)
            return _output = getAllNative();
        return _output;
    }

    /**
      (SLOW)
     **/
    public function map<T>(fn: Item -> T) {
        return new FCursorTransform(this, function(items) {
            return items.map( fn );
        });
    }

    public function groupBy(expr: Value) {
        return new ValueGroupedCursorTransform(this, expr);
    }

    public function prop(name: String) {
        return new ExtractPropCursorTransform(this, name);
    }

    public function pick(names: Array<String>) {
        return new PickPropsCursorTransform(this, names);
    }

    public function without(names: Array<String>) {
        return new TrimPropsCursorTransform(this, names);
    }

    /**
      build and return the lambda function used as a predicate which applies the supplied checks to each document
     **/
    public function predicateLambda():(item: Item) -> Bool {
        return function(itm: Item):Bool {
            return this.predicate(
                qi.ctx.setDoc(itm.asObject()),
                itm
            );
        };
    }

    public inline function forEach(fn: Item -> Void) {
        return getAllNative().iter( fn );
    }

    /**
      perform FIND operation for a single document
     **/
    public function getOneNative():Null<Item> {
        // get list of possible (candidate) results
        var ca = candidates();
        if (ca.empty()) return null;

        // perform further filtering by [predicate]
        if (checkNode != null && !(checkNode is pmdb.ql.ast.nodes.NoCheck)) {
            return ca.find(function(itm: Item):Bool {
                return this.predicate(qi.ctx.setDoc(itm.asObject()), itm);
            });
        }

        return ca[0];
    }

    /**
      skip the Resultset step and just get the results of [this] FIND operation as an array directly
     **/
    public function getAllNative():Array<Item> {
        // get list of possible (candidate) results
        var res = candidates();
        if (res.empty()) return [];
        if (res.empty())
            return [];

        // perform further filtering by [predicate]
        if (checkNode != null && !(checkNode is pmdb.ql.ast.nodes.NoCheck)) {
            res = res.filter(function(itm: Item):Bool {
                return this.predicate(qi.ctx.setDoc(itm.asObject()), itm);
            });
        }

        // perform result-sorting
        if (order != null) {
            var crit:Array<{key:String, direction:Int}> = [];
            switch order {
                case SimpleSort(key, direction):
                    crit.push({
                        key: key,
                        direction: direction
                    });

                case CompoundSort(_.asObject()=>o):
                    for (k in o.keys()) {
                        crit.push({
                            key: k,
                            direction: o[k]
                        });
                    }
            }
            res.sort(function(a:Item, b:Item):Int {
                var x = a.asObject(), y = b.asObject();
                var c, cmp;
                for (i in 0...crit.length) {
                    c = crit[i];
                    cmp = c.direction * Arch.compareThings(x.dotGet(c.key), y.dotGet(c.key));
                    if (cmp != 0)
                        return cmp;
                }
                return 0;
            });
        }

        // yield results
        return res;
    }

    public function iterate():FindIteration<Item> {
        assert( canIterate );
        if (itr == null)
            itr = new FindIteration( this );
        return itr;
    }
    public inline function itrCandidates() {
        return this.store.getCandidates(cast this.searchIndex).iterator();
    }

    public function sort(criteria: Dynamic<SortOrder>):FindCursor<Item> {
        this.order = CompoundSort( criteria );
        return this;
    }

    function getBounds():Null<{limit:Int, offset:Int}> {
        return 
            if (limit == null && offset == null) null;
            else {
                limit: (limit == null ? -1 : limit),
                offset: (offset == null ? 0 : offset)
            };
    }

/* === Variables === */

    public var itr(default, null): Null<FindIteration<Item>> = null;

    public var limit(default, null): Null<Int> = null;
    public var offset(default, null): Null<Int> = null;

    public var order(default, null): Null<ResultSort<Item>> = null;

    public var _output(default, null): Null<Array<Item>> = null;

    var _compile(default, null): Bool = false;
    var _filter(default, null):Bool = true;
    var _filterc(default, null): Null<QueryInterp -> Bool> = null;
}

class FindIteration<T> {
    public function new(cursor) {
        this.cursor = cursor;
        this.itr = cast cursor.caret.iterator();
    }

    public function hasNext():Bool {
        return itr.hasNext();
    }

    public function next():T {
        return itr.next();
    }

    public var cursor(default, null): FindCursor<T>;
    public var itr(default, null): IndexItemCaretIterator<T>;
}

class PagedFindIteration<T> {
    public function new(cursor, iter, size) {
        this.cursor = cursor;
        this.itr = iter;
        this.length = size;
    }

    public var cursor(default, null): FindCursor<T>;
    public var itr(default, null): FindIteration<T>;

    public var length(default, null): Int = 0;
}

class FindResultPage<T> {
    public function new(cursor, docs) {
        this.cursor = cursor;
        this.documents = docs;
        this.length = documents.length;
    }

    public var cursor(default, null): FindCursor<T>;
    public var documents(default, null): Array<T>;

    public var length(default, null): Int;
}

/**
  represents some form of data which is derived from an ICursor<?> instance
 **/
class CursorDerivative<TIn, TOut> implements ICursor<TOut> {
    /* Constructor Function */
    public function new(prev) {
        this.prev = prev;
        this._output = null;
    }

/* === Methods === */

    private function _transform(data: TIn):TOut {
        throw 'Not Implemented';
    }

    public function exec():TOut {
        if (_output == null)
            return _output = _transform(prev.exec());
        return _output;
    }

    public function getRoot():Null<FindCursor<Dynamic>> {
        var c:ICursor<Dynamic> = this;
        while (c != null) {
            if ((c is CursorDerivative<Dynamic, Dynamic>)) {
                c = cast(c, CursorDerivative<Dynamic, Dynamic>).prev;
            }

            if ((c is FindCursor<Dynamic>)) {
                return cast c;
            }
        }
        return null;
    }

/* === Variables === */

    public var prev(default, null): ICursor<TIn>;
    public var _output(default, null): Null<TOut>;
}

class CursorPassThrough<T> extends CursorDerivative<T, T> {
    override function _transform(data: T):T {
        return data;
    }
}

class FCursorTransform<In, Out> extends CursorDerivative<In, Out> {
    public function new(cursor, fn:In -> Out) {
        super( cursor );

        transform = fn;
    }

/* === Methods === */

    override function _transform(input: In):Out {
        return transform( input );
    }

/* === Variables === */

    private var transform(default, null): In -> Out;
}

class GroupedCursorTransform<Item, Key> extends CursorDerivative<Array<Item>, Array<Pair<Key, Array<Item>>>> {
    /* Constructor Function */
    public function new(cursor) {
        super(cursor);
    }

/* === Methods === */

    /**
      transform [this]'s input into a grouped set
     **/
    override function _transform(items: Array<Item>) {
        var pairs = items.map(i -> new Pair(groupId(i), i));
        pairs.sort(function(a, b) {
            return Arch.compareThings(a.key, b.key);
        });
        var ga = group( pairs );
        return ga;
    }

    private static function group<Key, Item>(pairs: Array<Pair<Key, Item>>):Array<Pair<Key, Array<Item>>> {
        if (pairs.length == 0) return [];

        var index = 0;
        var curGroup = new Pair(pairs[0].key, new Array());
        var groups = [curGroup];

        while (index < pairs.length - 1) {
            if (Arch.areThingsEqual(curGroup.key, pairs[index].key)) {
                curGroup.value.push(pairs[index].value);
            }
            else {
                groups.push(curGroup = new Pair(pairs[index].key, new Array()));
            }

            ++index;
        }

        return groups;
    }

    private function groupId(item: Item):Key {
        throw 'Unimpl';
    }

/* === Variables === */

    private var dict(default, null): Hash<Key, Array<Item>>;
}

class FGroupedCursorTransform<Item, Key> extends GroupedCursorTransform<Item, Key> {
    private var key(default, null): Item -> Key;
    public function new(cursor, fn) {
        super( cursor );

        this.key = fn;
    }

    override function groupId(item: Item):Key {
        return key( item );
    }
}

class ValueGroupedCursorTransform<Item> extends GroupedCursorTransform<Item, Dynamic> {
    private var value(default, null): Value;
    private var get(default, null): Dynamic -> Dynamic;

    public function new(cursor, value) {
        super(cursor);

        this.value = value;
        var root = getRoot();
        if (root == null)
            throw 'Invalid call';
        this.value = @:privateAccess this.value.compile( root.qi );
        var node = this.value.getNode();
        this.get = node.compile().bind(_, []);
    }

    override function groupId(item: Item):Dynamic {
        return get( item );
    }
}

class ExtractPropCursorTransform<Item> extends CursorDerivative<Array<Item>, Array<Dynamic>> {
    /* Constructor Function */
    public function new(cursor, name) {
        super(cursor);
        this.fieldName = name;
    }

    override function _transform(items: Array<Item>) {
        return items.map(function(item: Item) {
            return Arch.getDotValue(cast item, fieldName);
        });
    }

    private var fieldName(default, null): String;
}

class PickPropsCursorTransform<Item> extends CursorDerivative<Array<Item>, Array<Dynamic>> {
    public function new(cursor, attrs) {
        super( cursor );

        this.fields = attrs;
    }

    override function _transform(items: Array<Item>) {
        return items.map(function(item: Item) {
            final o:Object<Dynamic> = Object.ofStruct(cast item);
            return o.pick( fields );
        });
    }

    private var fields(default, null): Array<String>;
}

class TrimPropsCursorTransform<Item> extends CursorDerivative<Array<Item>, Array<Dynamic>> {
    public function new(cursor, attrs) {
        super( cursor );

        this.fields = attrs;
    }

    override function _transform(items: Array<Item>) {
        return items.map(function(item: Item) {
            final o:Object<Dynamic> = Object.ofStruct(cast item);
            return o.without( fields );
        });
    }

    private var fields(default, null): Array<String>;
}

class Pair<Key, Value> {
    public final key: Key;
    public final value: Value;

    public function new(k, v) {
        this.key = k;
        this.value = v;
    }
}

interface ICursor<Data> {
    function exec():Data;

    var _output(default, null):Null<Data>;
}

enum ResultSort<T> {
    SimpleSort(field:String, sort:SortOrder);
    CompoundSort(fields: Dynamic<SortOrder>);
}

enum abstract SortOrder (Int) from Int to Int {
    var Asc = -1;
    var Desc = 1;
}
