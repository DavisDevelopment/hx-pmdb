package pmdb.core.query;

import tannus.ds.Set;
import tannus.ds.Lazy;
import tannus.ds.Ref;

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
import pmdb.ql.ast.nodes.update.*;
import pmdb.ql.ast.nodes.value.*;
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

@:access( pmdb.core.Store )
class StoreQueryInterface<Item> {
    /* Constructor Function */
    public function new(store) {
        this.store = store;

        if (SANDBOX) {
            this.parser = new QlParser();
            parser.useSchema( store.schema );
            this.compiler = new QueryCompiler();
            compiler.use( store.schema );

            this.ctx = new QueryInterp( store );
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

    inline function compileHsExprToPredicate(expr: hscript.Expr):PredicateExpr {
        return parser.readPredicate( expr );
    }

    inline function compileStringToPredicate(s: String):PredicateExpr {
        return parser.parsePredicate( s );
    }

    public inline function criterion(c:Criterion<Item>, prep=false):Criterion<Item> {
        return c;
    }

    public function mutation(update:Mutation<Item>, prep=true):Mutation<Item> {
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

    public function check(where: Criterion<Item>):Check {
        return where.compile( this ).toCheck();
    }

    /**
      search the Store<Item>
     **/
    public function find(where:Criterion<Item>, precompile:Bool=false):FindCursor<Item> {
        var where = check( where );

        return getCheckCursor(where, precompile);
    }

    public function findAll(where:Criterion<Item>, ?precompile):Array<Item> {
        return find(where, precompile).getAllNative();
    }

    /**
      apply some transformation to the Store<Item>
     **/
    public function update(how:Mutation<Item>, ?where:Criterion<Item>, precompile:Bool=false):UpdateCursor<Item> {
        how = mutation( how );
        return getUpdateCursor(how, where, precompile);
    }

    //
    public function bffind(where, prec=false) {
        //where = criterion( where );
        return store.getAllData().filter(function(item: Item):Bool {
            return where.eval(globalCtx.setDoc(cast item));
        });
    }

    /**
      get the Index (and accompanying constraints thereon) to be used for traversal
     **/
    @:noCompletion
    public function getSearchIndex(check: Check):QueryIndex<Any, Item> {
        var suggestedIndex:QueryIndex<Any, Item> = cast (check.getExpr().getTraversalIndex(store.indexes));
        if (suggestedIndex == null)
            suggestedIndex = cast new QueryIndex( store.pid );
        return suggestedIndex;
    }

    /**
      build and return the QueryCursor object used by the 'update' directive
     **/
    public inline function getUpdateCursor(mut:Mutation<Item>, ?predicate:Criterion<Item>, precompile:Bool):UpdateCursor<Item> {
        return new UpdateCursor(this, mut, predicate, precompile);
    }

    /**
      build a Cursor for the given Check
     **/
    public inline function getCheckCursor(check:Check, precompile:Bool):FindCursor<Item> {
        return new FindCursor(this, check, precompile);
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

    public static var globalCtx: QueryInterp = new QueryInterp();
    public static var globalParser = new QlParser();
    public static var globalCompiler = new QueryCompiler();


    static inline var SANDBOX = true;
}

