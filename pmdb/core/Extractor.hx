package pmdb.core;

import tannus.ds.*;
import tannus.math.TMath as M;

import pmdb.ql.ts.DataType;
import pmdb.core.Comparator;
import pmdb.core.Equator;

import haxe.macro.Expr;
import haxe.macro.Context;

using StringTools;
using tannus.ds.StringUtils;
using tannus.async.OptionTools;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.FunctionTools;
using pmdb.ql.ts.DataTypes;

using haxe.macro.Tools;
using haxe.macro.ExprTools;
using tannus.macro.MacroTools;

@:forward
abstract Extractor<From, To> (Extract<From, To>) from Extract<From, To> to Extract<From, To> {
    public static function betty() {
        return SelfExtract.make();
    }
}

interface Extract<Src, T> {
    function extract(source: Src):T;
}

class SelfExtract<T> implements Extract<T, T> {
    function new() {}
    public inline function extract(v: T):T {
        return v;
    }
}
