package pmdb.core.query;

import tannus.ds.Lazy;

import pmdb.ql.types.*;
import pmdb.ql.ts.*;
import pmdb.ql.ts.DataType;
import pmdb.core.ds.AVLTree.AVLTreeNode as Leaf;
import pmdb.core.ds.LazyItr;
import pmdb.core.query.IndexItemCaret;
import pmdb.core.Store;

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
import Slambda.fn;
import Std.is as isType;
import pmdb.core.Assert.assert;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.async.OptionTools;
using tannus.ds.IteratorTools;
using tannus.FunctionTools;
using pmdb.ql.ast.Predicates;

/**
  TODO: optimize performance for FindCursor<Item> instances where [check] is unspecified
 **/
@:access(pmdb.core.query.StoreQueryInterface)
class FindCursor<Item> extends QueryCursor<Item, Array<Item>> {
    public function new(qi, ?check:Criterion<Item>, compile = false, noInit = false) {
        super( qi );

        if (check == null)
            check = new pmdb.ql.ast.nodes.NoCheck();
        filter = ensureFilter( check );

        _compile = compile;

        if ( !noInit ) {
            init();
        }
    }

/* === Methods === */

    override function onIndexItemCaret(caret: IndexItemCaret<Item>) {
        super.onIndexItemCaret( caret );

        if (_compile)
            _filterc = ensureFilter( filter ).compile();
    }

    /**
      "execute" the FIND operation represented by [this]
     **/
    override function exec():Array<Item> {
        return getAllNative();
    }

    /**
      skip the Resultset step and just get the results of [this] FIND operation as an array directly
     **/
    public function getAllNative():Array<Item> {
        var res = candidates();
        if (filter != null && !(filter is pmdb.ql.ast.nodes.NoCheck)) {
            var check = ensureFilter( filter );
            res = res.filter(function(itm: Item):Bool {
                return
                if ( _compile )
                    _filterc(StoreQueryInterface.globalCtx.setDoc(cast itm));
                else
                    check.eval(StoreQueryInterface.globalCtx.setDoc(cast itm));
            });
        }
        return res;
    }

    public function iterate():FindIteration<Item> {
        assert(canIterate);
        if (itr == null)
            itr = new FindIteration( this );
        return itr;
    }

    function candidates():Array<Item> {
        return this.searchIndex.index.getAll();
    }

    inline function getBounds():{limit:Int, offset:Int} {
        return {
            limit: (limit == null ? -1 : limit),
            offset: (offset == null ? 0 : offset)
        };
    }

/* === Variables === */

    public var itr(default, null): Null<FindIteration<Item>> = null;

    public var limit(default, null): Null<Int> = null;
    public var offset(default, null): Null<Int> = null;

    public var order(default, null): Null<ResultOrder<Item>> = null;

    var _compile(default, null): Bool = false;
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

class ResultOrderRoot<T> {
    public function sort(c:FindCursor<T>, docs:Array<T>) {
        throw new NotImplementedError();
    }
}

class FnResultOrder<T> extends ResultOrderRoot<T> {
    public function new(fn) {
        this.fn = fn;
    }

    override function sort(cursor:FindCursor<T>, docs:Array<T>) {
        docs.sort( fn );
    }

    private var fn(default, null): T->T->Int;
}

class ComparatorResultOrder<T> extends ResultOrderRoot<T> {
    public function new(comparator) {
        c = comparator;
    }

    override function sort(cursor:FindCursor<T>, docs:Array<T>) {
        docs.sort((a, b) -> c.compare(a, b));
    }

    private var c(default, null): Comparator<T>;
}

@:forward
abstract ResultOrder<T> (ResultOrderRoot<T>) from ResultOrderRoot<T> to ResultOrderRoot<T> {
    @:from
    public static inline function ofFunc<T>(fn: T -> T -> Int):ResultOrder<T> {
        return new FnResultOrder( fn );
    }

    @:from
    public static inline function ofComparator<T>(c: Comparator<T>):ResultOrder<T> {
        return new ComparatorResultOrder( c );
    }
}
