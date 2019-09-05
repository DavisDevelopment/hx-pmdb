package pmdb.ql.ts;


import pmdb.ql.ts.DataType;
import pmdb.core.TypedValue;

import haxe.ds.Option;


using StringTools;

using pmdb.core.Utils;
using pmdb.ql.ts.DataTypes;

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
