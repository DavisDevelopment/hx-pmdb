package pmdb.ql.ast.builtins;

import tannus.math.TMath as M;

import pmdb.ql.ts.TypedData;
import pmdb.ql.ast.BuiltinFunction;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.FunctionTools;
using pmdb.ql.ts.DataTypes;

class Sub extends BuiltinFunction {
    public function new() {
        super('__sub__');
    }

/* === Methods === */

    override function apply(args: Array<TypedData>):TypedData {
        //throw '[=| TODO(builtins) |=]';
        return (args[0].getUnderlyingValue() - args[1].getUnderlyingValue()).typed();
    }

    @:keep @fn('Float', 'Float', 'Float')
    inline function _num_num(x:Float, y:Float):Float {
        return x - y;
    }

    @:keep @fn('Float', 'Any', 'Float')
    inline function _num(x:Float, y:Dynamic):Float {
        if ((y is Float)) {
            return _num_num(x, cast(y, Float));
        }
        else return Math.NaN;
    }

    @:keep @fn('Array', 'Any', 'Array')
    inline function _list(x:Array<Dynamic>, y:Dynamic):Array<Dynamic> {
        var list = x.copy();
        if ((y is Array<Dynamic>)) {
            for (v in cast(y, Array<Dynamic>)) {
                list.remove( v );
            }
        }
        else {
            list.remove( y );
        }
        return list;
    }

    @:keep @fn('Date', 'Date', 'Date')
    inline function _date_date(x:Date, y:Date):Date {
        return Date.fromTime(_num_num(x.getTime(), y.getTime()));
    }

    @:keep @fn('Date', 'Float', 'Date')
    inline function _date_num(x:Date, y:Float):Date {
        return _date_date(x, Date.fromTime( y ));
    }
}
