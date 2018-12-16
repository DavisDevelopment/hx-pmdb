package pmdb.core.query;

import tannus.ds.Set;
import tannus.ds.Lazy;
import tannus.ds.Ref;
import tannus.io.Signal;
import tannus.io.VoidSignal as VSignal;

import pmdb.ql.types.*;
import pmdb.ql.ts.*;
import pmdb.ql.ts.DataType;
import pmdb.ql.ts.DocumentSchema;
import pmdb.ql.ast.BoundingValue;
import pmdb.core.ds.AVLTree;
import pmdb.core.ds.AVLTree.AVLTreeNode as Leaf;
import pmdb.core.ds.*;
import pmdb.core.*;
import pmdb.core.query.IndexCaret;
import pmdb.core.Store;

import pmdb.ql.*;
import pmdb.ql.ast.*;
import pmdb.ql.ast.nodes.*;
import pmdb.ql.ast.ASTError;
import pmdb.ql.ts.TypeSystemError;
import pmdb.ql.ast.QueryCompiler;
import pmdb.ql.QueryIndex;
import pmdb.ql.hsn.QlParser;

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

@:access(pmdb.core.query.StoreQueryInterface)
class QueryCursor<Item, ExeOut> extends QueryCursorBase<Item> {
    /* Constructor Function */
    public function new(q) {
        super( q );
    }

    public function exec():ExeOut {
        throw 'ni';
    }
}

@:access(pmdb.core.query.StoreQueryInterface)
class QueryCursorBase<Item> {
    /* Constructor Function */
    public function new(qi: QInterface<Item>):Void {
        this.qi = qi;
        this.store = qi_store( qi );
        this.searchIndex = null;
        this.filter = null;
    }

/* === Methods === */

    /**
      method which is invoked to 'begin' execution of the associated Query
     **/
    public function init() {
        assert(filter != null, new Invalid(filter, Check));
        
        if (searchIndex == null) {
            initSearchIndex();
        }

        assert(searchIndex != null, new Invalid(searchIndex, QueryIndex));
        onSearchIndexObtained( searchIndex );
    }

    /**
      method invoked to initialize the search index
     **/
    private function initSearchIndex() {
        //filter = filter.or((Criterion.fromPredicateExpr(PredicateExpr.PNoOp)));
        searchIndex = qi.getSearchIndex( filter );
    }

    /**
      method which is invoked when the [filter] attribute is assigned 
      in such a way that it [filter]'s pre-assignment value was "null",
      and obtains a post-assignment value that qualifies as non-null
     **/
    private function onFilterAssigned() {
        assert(filter != null, new Invalid(filter, Check));

        filter = ensureFilter( filter );
        searchIndex = qi.getSearchIndex( filter );
        onSearchIndexObtained( searchIndex );
    }

    /**
      method invoked when the QueryIndex to be used for store-traversal has been selected
     **/
    private function onSearchIndexObtained(idx: QueryIndex<Dynamic, Item>) {
        assert(idx != null, new Invalid(idx, QueryIndex));

        //var ii = IndexItemCaret.make(
            //qid.index,
            //new QueryCaret( qid ),
            //null,
            //(iic, item:Item) -> filter.eval(QInterface.globalCtx.setDoc( item ))
        //);
        var ii = createIndexItemCaret();

        // ...

        onIndexItemCaret( ii );
    }

    /**
      build and return the IndexItemCaret
     **/
    private function createIndexItemCaret():IndexItemCaret<Item> {
        var qc:QueryCaret<Item> = createQueryCaret();
        var check = ensureFilter( filter );
        qc.shouldYield = (function(item: Item):Bool {
            return check.eval(QInterface.globalCtx.setDoc(cast item));
        });

        return qc;
    }

    /**
      build and return the QueryCaret object
     **/
    private function createQueryCaret():QueryCaret<Item> {
        return QueryCaret.create( searchIndex );
    }

    /**
      invoked with the IndexItemCaret object to be used to traverse the Store
      ...
      this method is logically where the meat of the actual query-logic should happen
     **/
    private function onIndexItemCaret(caret: IndexItemCaret<Item>) {
        this.caret = caret;
        canIterate = true;
        
        //TODO: from here, link some other methods with actions on [iic]
    }

    /**
      ensure that [filter] is properly and entirely initialized
     **/
    inline function ensureFilter(filter: Criterion<Item>):Check {
        return qi.check( filter );
    }

    static inline function qi_store<T>(q: QInterface<T>):Store<T> {
        return q.store;
    }

/* === Properties === */

    public var filter(default, null): Criterion<Item>;
    public var caret(default, null): IndexItemCaret<Item>;

/* === Variables === */

    public var store(default, null): Store<Item>;
    public var searchIndex(default, null):QueryIndex<Dynamic, Item>;
    public var qi(default, null): QInterface<Item>;
    //public var iic(default, null): Null<IndexItemCaret<Item>>;

    private var canIterate(default, null): Bool = false;
}

typedef QInterface<T> = pmdb.core.query.StoreQueryInterface<T>;
