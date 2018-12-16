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

@:forward
abstract Criterion<T> (ECriterion<T>) from ECriterion<T> to ECriterion<T> {
/* === Methods === */

    public inline function isCompiled():Bool {
        return this.match(CompiledCriterion(_));
    }

    public inline function isParsed() {
        return this.match(CompiledCriterion(_)|PredicateExprCriterion(_));
    }

    @:to
    public inline function toCheck():Check {
        return switch ( this ) {
            case CompiledCriterion(check): check;
            default: throw new Error('Criterion $this not compiled');
        }
    }

    @:access( pmdb.core.query.StoreQueryInterface )
    public inline function mkPredicateExpr(parse = false, ?qi:StoreQueryInterface<Dynamic>):PredicateExpr {
        return switch ( this ) {
            case CompiledCriterion(x): x.getExpr();
            case PredicateExprCriterion(x): x;
            case HScriptExprCriterion(x) if (parse && qi != null): qi.compileHsExprToPredicate(x);
            case StringCriterion(x) if (parse && qi != null): qi.compileStringToPredicate(x);
            default: throw new Error('Invalid call');
        }
    }

    @:to public inline function toPredicateExpr():PredicateExpr return mkPredicateExpr(false, null);

    public inline function compile(q: StoreQueryInterface<T>):Criterion<T> {
        return _compile(this, q);
    }

    @:access( pmdb.core.query.StoreQueryInterface )
    static function _compile<T>(c:Criterion<T>, i:StoreQueryInterface<T>):Criterion<T> {
        switch c {
            case CompiledCriterion(check):
                return CompiledCriterion(i.init_check( check ));

            case PredicateExprCriterion(expr):
                return _compile(CompiledCriterion(i.compile_predicate(expr)), i);

            case HScriptExprCriterion(expr):
                return _compile(CompiledCriterion(i.compile_predicate(i.compileHsExprToPredicate(expr))), i);

            case StringCriterion(code):
                return _compile(CompiledCriterion(
                    i.compile_predicate(i.compileStringToPredicate(code))
                ), i);
        }
    }

/* === Casting Methods === */

    @:from
    public static inline function fromCheck<T>(c: Check):Criterion<T> {
        return CompiledCriterion( c );
    }

    @:from
    public static inline function fromHsExpr<T>(e: hscript.Expr):Criterion<T> {
        //return fromPredicateExpr(StoreQueryInterface.globalParser.readPredicate( e ));
        return HScriptExprCriterion( e );
    }

    @:from
    public static inline function fromPredicateExpr<T>(e: PredicateExpr):Criterion<T> {
        return PredicateExprCriterion( e );
    }

    @:from
    public static inline function fromString<T>(s: String):Criterion<T> {
        return StringCriterion( s );
    }

    public static function noop():Criterion<Dynamic> {
        return CompiledCriterion(new NoCheck());
    }
}

enum ECriterion<T> {
    StringCriterion(value: String);
    PredicateExprCriterion(value: PredicateExpr);
    HScriptExprCriterion(value: hscript.Expr);

    CompiledCriterion(value: Check);
}
