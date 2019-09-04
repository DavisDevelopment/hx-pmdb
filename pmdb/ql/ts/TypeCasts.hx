package pmdb.ql.ts;


import pmdb.ql.ts.DataType;
import pmdb.core.TypedValue;

import haxe.ds.Option;

import haxe.macro.Expr;
import haxe.macro.Context;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.ds.DictTools;
using tannus.ds.MapTools;
using tannus.async.OptionTools;
using tannus.FunctionTools;

using pmdb.core.Utils;
using pmdb.ql.ts.DataTypes;

using haxe.macro.Tools;
using haxe.macro.ExprTools;
using tannus.macro.MacroTools;

/**
  not really "casts", per se; more like coercions
 **/
class TypeCasts {
    public static function asBool(x: Dynamic):Bool {
        return cast(x, Bool);
    }
    public static function asFloat(x: Dynamic):Float {
        return cast(x, Float);
    }
    public static function asArray(x: Dynamic):Array<Dynamic> {
        return cast (x : Array<Dynamic>);
    }
}
