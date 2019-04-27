package pmdb;

import pm.Lazy;

import haxe.macro.Expr;
import haxe.macro.Context;

using StringTools;
using pm.Strings;
using pm.Numbers;
using Lambda;
using pm.Arrays;
using pm.Functions;

class Macros {
    public static macro function lee<X>(e: ExprOf<X>):ExprOf<Void->X> {
        return elee( e );
    }
    public static macro function lve(e: Expr):ExprOf<Void->Void> {
        return elee( e );
    }

    public static macro function lazy<T>(e: ExprOf<T>):ExprOf<Lazy<T>> {
        return elazy( e );
    }

    public static macro function monad(e: Expr):ExprOf<Void -> Void> {
        return elve( e );
    }

    public static macro function clock(e: Expr):ExprOf<Float> {
        return macro pmdb.Globals.measure(${elve(e)});
    }

#if macro

    static function elee<T>(e: ExprOf<T>):ExprOf<Void -> T> {
        return macro (() -> $e);
    }

    static function elve<T>(e: Expr):ExprOf<Void -> Void> {
        return macro (() -> {
            ${e};
            pm.Functions.noop();
        });
    }

    static function elazy<T>(e: ExprOf<T>):ExprOf<Lazy<T>> {
        return macro pm.Lazy.ofFn(${elee(e)});
    }

#end
}
