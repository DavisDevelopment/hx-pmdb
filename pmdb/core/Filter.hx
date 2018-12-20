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
abstract Filter<T> (FilterObject<T>) from FilterObject<T> to FilterObject<T> {
    public static function ass() {
        AcceptAllFilter.
    }
}

interface FilterObject<T> {
    function match(value: T):Bool;
}

class AcceptAllFilter implements FilterObject<Dynamic> implements pmdb.core.ds.Singleton {
    inline function new() {}
    inline public function match(x: Dynamic):Bool return true;
}
