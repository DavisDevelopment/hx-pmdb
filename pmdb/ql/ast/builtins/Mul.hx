package pmdb.ql.ast.builtins;

import tannus.math.TMath as M;

import pmdb.ql.ast.BuiltinFunction;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.FunctionTools;
using pmdb.ql.ts.DataTypes;

class Mul extends BuiltinFunction {
    public function new() {
        super('__mul__');
    }

/* === Methods === */

    @:keep @fn('Float', 'Float', 'Float')
    inline function _num_num(x:Float, y:Float):Float {
        return x * y;
    }

    @:keep @fn('Float', 'Any', 'Float')
    inline function _num(x:Float, y:Dynamic):Float {
        if ((y is Float)) {
            return _num_num(x, cast(y, Float));
        }
        else return Math.NaN;
    }

    @:keep @fn('Array', 'Int', 'Array')
    inline function _list(x:Array<Dynamic>, y:Int):Array<Dynamic> {
        return x.times( y );
    }

    @:keep @fn('String', 'Int', 'String')
    inline function _string(x:String, y:Int):String {
        return x.times( y );
    }
}
