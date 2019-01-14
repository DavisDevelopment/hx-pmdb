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
import pmdb.ql.ast.Value.ValueExpr;
import pmdb.ql.ast.nodes.*;
import pmdb.ql.ast.nodes.update.*;
import pmdb.ql.ast.nodes.value.*;
import pmdb.ql.ast.QueryCompiler;
import pmdb.ql.QueryIndex;
import pmdb.ql.hsn.QlParser;
import pmdb.core.query.Value;

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

@:access( pmdb.core.Store )
class StoreQueryInterface<Item> {
    /* Constructor Function */
    public function new(store) {
        this.store = store;

        if (SANDBOX) {
            this.ctx = new QueryInterp( store );

            this.parser = new QlParser();
            parser.useSchema( store.schema );

            this.compiler = new QueryCompiler();
            compiler.with( ctx ).use( store.schema );
        }
        else {
            this.parser = globalParser;
            this.compiler = globalCompiler;
            this.ctx = globalCtx;
        }
    }

/* === Methods === */

    /**
      prepares / initializes the given Criterion<T>
     **/
    function init_check(check:Check, prep=true):Check {
        if (!prep || check.hasLabel(':initialized'))
            return check;

        ctx.setStore( store );

        //trace('initializing query-tree');
        check.initAll();

        //trace('linking query-tree to interpreter');
        check.attachInterpAll( ctx );

        //trace('computing typing information');
        check.iter(c -> c.computeTypeInfo(), true);

        //trace('optimizing query-tree');
        check = check.optimize();
        check.addLabel(':initialized');

        return check;
    }

    inline function compile_predicate(expr: PredicateExpr):Check {
        return compiler.compilePredicate( expr );
    }

    inline function compileUpdateExpr(expr: UpdateExpr):Update {
        return compiler.compileUpdate( expr );
    }

    inline function compileHsExprToPredicate(expr: hscript.Expr):PredicateExpr {
        return parser.readPredicate( expr );
    }

    inline function compileHsExprToUpdate(expr: hscript.Expr):UpdateExpr {
        return parser.readUpdate( expr );
    }

    inline function compileStringToPredicate(s: String):PredicateExpr {
        return parser.parsePredicate( s );
    }

    inline function compileStringToUpdate(s: String):UpdateExpr {
        return parser.parseUpdate( s );
    }

    inline function compileStringToValue(s: String):ValueExpr {
        return parser.parseValue( s );
    }

    inline function compileHsExprToValue(e: hscript.Expr):ValueExpr {
        return parser.readValue( e );
    }

    inline function compileValueExpr(e: ValueExpr):ValueNode {
        return compiler.compileValueExpr( e );
    }

    public inline function criterion(c:Criterion<Item>, prep=false):Criterion<Item> {
        return c;
    }

    public function updateNode(m:Mutation<Item>):Update {
        return m.compile( this ).toUpdate();
    }

    public function init_update(update:Update, prep=true):Update {
        if (!prep || update.hasLabel(':initialized'))
            return update;
        ctx.setStore( store );
        update.initAll();
        update.attachInterpAll( ctx );
        update.iter(c -> c.computeTypeInfo(), true);

        update = update.optimize();
        update.addLabel(':initialized');

        return update;
    }

    public inline function mutation(m:Mutation<Item>, prep=false):Mutation<Item> {
        return m;
    }

    public inline function value(v:Value, prep=false):Value {
        return v;
    }

    public inline function valueNode(v: Value):ValueNode {
        return v.compile( this ).getNode();
    }

    public function check(where: Criterion<Item>):Check {
        return where.compile( this ).toCheck();
    }

    /**
      build and return the QueryCursor object used by the 'update' directive
     **/
    public inline function getUpdateCursor(mut:Mutation<Item>, ?predicate:Criterion<Item>, precompile:Bool):UpdateCursor<Item> {
        return new UpdateCursor(store, mut, predicate, precompile);
    }

    /**
      build a Cursor for the given Check
     **/
    public inline function getCheckCursor(check:Check, precompile:Bool):FindCursor<Item> {
        return new FindCursor(store, check, precompile);
    }

    /**
      search the Store<Item>
     **/
    public function find(where:Criterion<Item>, precompile:Bool=false):FindCursor<Item> {
        var where = check( where );

        return getCheckCursor(where, precompile);
    }

    public function findOne(where:Criterion<Item>, precompile:Bool=false):Null<Item> {
        return find(where, precompile).getOneNative();
    }

    public function findAll(where:Criterion<Item>, ?precompile):Array<Item> {
        return find(where, precompile).getAllNative();
    }

    /**
      apply some transformation to the Store<Item>
     **/
    public function update(how:Mutation<Item>, ?where:Criterion<Item>, precompile:Bool=false):UpdateCursor<Item> {
        return getUpdateCursor(how, where, true);
    }

    //
    public function bffind(where, prec=false) {
        return store.getAllData().filter(function(item: Item):Bool {
            return where.eval(globalCtx.setDoc(cast item));
        });
    }

    /**
      get the Index (and accompanying constraints thereon) to be used for traversal
     **/
    public function getSearchIndex(check: Check):QueryIndex<Any, Item> {
        var suggestedIndex:QueryIndex<Any, Item> = cast (check.getExpr().getTraversalIndex(store.indexes));
        if (suggestedIndex == null)
            suggestedIndex = cast new QueryIndex( store.pid );
        return suggestedIndex;
    }
    public function _getSearchIndex(predicate: PredicateExpr):Null<QueryIndex<Any, Item>> {
        //var secondary = 
        return null;
    }


    /**
      cast the given Dynamic value to an Object
     **/
    private static inline function obj(o: Dynamic):Object<Dynamic> {
        return cast o;
    }

/* === Variables === */

    public var store(default, null): Store<Item>;
    public var ctx(default, null): QueryInterp;

    public var parser(default, null): QlParser;
    public var compiler(default, null): QueryCompiler;

    public static var globalParser = new QlParser();
    public static var globalCompiler = new QueryCompiler();
    public static var globalCtx: QueryInterp = new QueryInterp();

    static inline var SANDBOX = true;
}

