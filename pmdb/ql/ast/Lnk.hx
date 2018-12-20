package pmdb.ql.ast;

import pmdb.ql.ts.DataType;
import pmdb.ql.ast.Value;
import pmdb.ql.ast.ValueResolver;
import pmdb.ql.ast.PredicateExpr;
import pmdb.core.Error;
import pmdb.core.Object;

import pmdb.ql.ast.PredicateExpr as Pe;
import pmdb.ql.ast.Value.ValueExpr as Ve;

import haxe.Constraints.Function;
import haxe.ds.Either;
import haxe.ds.Option;
import haxe.PosInfos;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.FunctionTools;
using pmdb.ql.ts.DataTypes;
using pmdb.ql.ast.Predicates;

@:forward(resolve, compile, match, equals)
abstract Lnk<T> (Resolution<Object<Dynamic>, T>) from Resolution<Object<Dynamic>, T> to Resolution<Object<Dynamic>, T> {
    @:op(A & B)
    public inline function map<O>(fn: T -> O):Lnk<O> {
        return this.map( fn );
    }

    @:from
    public static inline function res<T>(r: Resolution<Dynamic, T>):Lnk<T> {
        return cast Resolution.res( r );
    }

    @:from
    public static inline function context<V>(get: Object<Dynamic> -> V):Lnk<V> {
        return RContextual( get );
    }

    @:from
    public static inline function expr(e: ValueExpr):Lnk<Dynamic> {
        return RExpression( e );
    }

    @:from
    public static inline function const<T>(c: T):Lnk<T> {
        return RConstant( c );
    }
}
