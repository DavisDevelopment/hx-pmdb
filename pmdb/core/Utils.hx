package pmdb.core;

import pmdb.ql.types.*;
import pmdb.ql.ts.DataType;

import haxe.ds.Either;
import haxe.ds.Option;
import haxe.extern.EitherType;
import haxe.Constraints.Function;

import hscript.Expr.Const;

using StringTools;

class Utils {}

class Anons {
    public static inline function dotGet<T>(o:Object<T>, key:String):T {
        return Arch.getDotValue(cast o, key);
    }
}

class Arrays {
    public static function append<T>(a:Array<T>, toAppend:Iterable<T>):Array<T> {
        for (v in toAppend)
            a.push( v );
        return a;
    }
}
