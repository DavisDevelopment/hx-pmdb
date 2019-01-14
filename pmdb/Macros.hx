package pmdb;

import tannus.io.*;
import tannus.ds.*;
import tannus.async.*;

import haxe.macro.Expr;
import haxe.macro.Context;

using StringTools;
using tannus.ds.StringUtils;
using tannus.math.TMath;
using Lambda;
using tannus.ds.ArrayTools;
using tannus.FunctionTools;
using tannus.macro.MacroTools;

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
            tannus.FunctionTools.noop();
        });
    }

    static function elazy<T>(e: ExprOf<T>):ExprOf<Lazy<T>> {
        return macro pmdb.core.ds.Lazy.ofFn(${elee(e)});
    }

#end
}
