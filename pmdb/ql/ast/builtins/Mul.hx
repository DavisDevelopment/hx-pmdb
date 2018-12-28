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

    @:keep 
    @fn('Float', 'Float', 'Float')
    function mulf3(x:Float, y:Float):Float {
        return x * y;
    }

    @:keep 
    @fn('int', 'int', 'int') 
    function muli3(x:Int, y:Int):Int return x * y;

    @:keep 
    @fn('Float', 'Any', 'Float')
    function mulfaf(x:Float, y:Dynamic):Float {
        if ((y is Float)) {
            return mulfaf(x, cast(y, Float));
        }
        else return Math.NaN;
    }

    @:keep 
    @fn('[int]', 'int', '[int]')
    inline function mullist(x:Array<Dynamic>, y:Int):Array<Dynamic> {
        return x.times( y );
    }

    @:keep @fn('String', 'Int', 'String')
    inline function mulstr(x:String, y:Int):String {
        return x.times( y );
    }
}
