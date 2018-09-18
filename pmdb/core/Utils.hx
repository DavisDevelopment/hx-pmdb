package pmdb.core;

import tannus.ds.Dict;
import tannus.ds.dict.DictKey;
import tannus.ds.Set;
import tannus.ds.Anon;
import tannus.ds.Lazy;
import tannus.ds.Ref;
import tannus.math.TMath as M;

import pmdb.ql.types.*;
import pmdb.ql.types.DataType;

import haxe.ds.Either;
import haxe.ds.Option;
import haxe.extern.EitherType;
import haxe.Constraints.Function;

import hscript.Expr.Const;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.ds.DictTools;
using tannus.ds.MapTools;
using tannus.async.OptionTools;
using tannus.FunctionTools;

class Utils {
    @:generic
    @:noUsing
    public static function setOf<T:DictKey>(values: Iterable<T>):Set<T> {
        var res:Set<T> = new Set();
        res.pushMany( values );
        return res;
    }
}

class Arrays {
    public static function append<T>(a:Array<T>, toAppend:Iterable<T>):Array<T> {
        for (v in toAppend)
            a.push( v );
        return a;
    }
}
