package pmdb.core.query;

import pmdb.ql.types.*;
import pmdb.ql.ts.*;
import pmdb.ql.ts.DataType;
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
    public function new(store) {
        super(store);
    }

    public function exec():ExeOut {
        throw 'ni';
    }
}

@:access(pmdb.core.Store)
@:access(pmdb.core.query.StoreQueryInterface)
class QueryCursorBase<Item> {
    /* Constructor Function */
    public function new(store: Store<Item>):Void {
        this.store = store;
        this.qi = store.q;
        this.searchIndex = null;
        this.criterion = null;
        this.checkNode = null;

        this.predicate = function(ctx, item:Item) {
            ctx.enterMode( Compute );
            var res = checkNode.eval(ctx.setDoc(item.asObject()));
            ctx.leaveMode();
            return res;
        }
    }

/* === Methods === */

    /**
      method which is invoked to 'begin' execution of the associated Query
     **/
    public function init() {
        assert(criterion != null, new Invalid(criterion, Check));
        assert(checkNode != null, new Invalid(checkNode, Check));
        
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
        /**
          [TODO] measure/record timing data for a few stress-tests with `usePlanner` set to `true` AND `false` respectively 
         **/
        var usePlanner = true;
        if ( usePlanner ) {
            var plan = qi.planSearch( checkNode );
            checkNode = compileCriterion(plan.check.get());
            searchIndex = cast plan.index.get();
            
        }
        else {
            searchIndex = qi.getSearchIndex( checkNode );
        }
    }

    /**
      method which is invoked when the [filter] attribute is assigned 
      in such a way that it [filter]'s pre-assignment value was "null",
      and obtains a post-assignment value that qualifies as non-null
     **/
    private function onCriterionAssigned() {
        assert(criterion != null, new Invalid(criterion, Check));

        checkNode = compileCriterion( criterion );
        var plan = qi.planSearch( checkNode );
        checkNode = compileCriterion(plan.check.get());
        searchIndex = cast plan.index.get();
        //trace(this.searchIndex);
        //trace(this.checkNode);

        onSearchIndexObtained( searchIndex );
    }

    /**
      method invoked when the QueryIndex to be used for store-traversal has been selected
     **/
    private function onSearchIndexObtained(idx: QueryIndex<Dynamic, Item>) {
        assert(idx != null, new Invalid(idx, QueryIndex));

        var ii = createIndexItemCaret();

        // ...

        onIndexItemCaret( ii );
    }

    /**
      build and return the IndexItemCaret
     **/
    private function createIndexItemCaret():IndexItemCaret<Item> {
        var qc:QueryCaret<Item> = createQueryCaret();

        qc.shouldYield = function(item: Item):Bool {
            //return check.eval(QInterface.globalCtx.setDoc(cast item));
            return predicate(qi.ctx, item);
        };

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
    inline function compileCriterion(filter: Criterion<Item>):Check {
        return qi.check( filter );
    }

    /**
      get the query result-candidates
     **/
    function candidates():Array<Item> {
        return store.getCandidates(cast searchIndex);
    }

    static inline function qi_store<T>(q: QInterface<T>):Store<T> {
        return q.store;
    }

/* === Properties === */

    public var criterion(default, null): Null<Criterion<Item>> = null;
    public var checkNode(default, null): Null<Check> = null;
    public var caret(default, null): IndexItemCaret<Item>;

/* === Variables === */

    /* the Store from which [this] Cursor was selected */
    public var store(default, null): Store<Item>;

    /* the search index being employed by [this] QueryCursor */
    public var searchIndex(default, null):QueryIndex<Dynamic, Item>;
    public var qi(default, null): QInterface<Item>;

    private var canIterate(default, null): Bool = false;
    private var predicate(default, null): (ctx:QueryInterp, doc:Item)->Bool;
}

typedef QInterface<T> = pmdb.core.query.StoreQueryInterface<T>;
