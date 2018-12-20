package pmdb.utils;

import haxe.macro.Expr;
import haxe.macro.Context;

import haxe.Constraints.Function as Func;

import pmdb.core.Object;
import pmdb.ql.ts.DataType.ObjectKind;

using Lambda;
using tannus.ds.ArrayTools;
using haxe.macro.ExprTools;
using tannus.macro.MacroTools;

class Tools {
    //
}

class Fn0x0 {
    //
}

class Fn1x0 {
    //
    public static inline function tap<T>(value:T, middle:T -> Void):T {
        middle( value );
        return value;
    }
}

class Fn1x1 {
    //
    public static inline function apply<A, B>(value:A, fn:A -> B):B {
        return fn( value );
    }

    //o
    public static inline function apply2<A, B, C>(value:A, fnA:A -> B, fnB:B -> C):C {
        return fnB(fnA( value ));
    }
}

//class FnRestMacros {
    //public static macro function composeRight<Fn:Func>(chain: Array<Expr>) {
        //if (chain.length == 0)
            //return macro {  };

        //var argspec = [];
        //var ret = null;
        //var level:Int = 0;

        //function consume(e: Expr) {
            //switch (e.expr) {
                //case EFunction(_, fn) if (level == 0):
                    //argspec = fn.args.copy();
                    //ret = fn.ret;

                //case EFunction(_, fn):
                    //ret = fn.ret;

                //default:
                    //ret = null;
            //}
        //}

        //var body:Expr = macro (@:rootCall null);
        //body = chain.reduce(
    //}
//}

class Dynamics {
    public static function asObject(o:Dynamic, safety = false):Object<Dynamic> {
        if (safety && !Reflect.isObject( o ))
            throw new ValueError(o, '$o cannot be cast to an Object');
        return cast Object.of( o );
    }
}
