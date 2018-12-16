package pmdb.ql.ast.builtins;

import tannus.math.TMath as M;

import pmdb.ql.ast.BuiltinFunction;
import pmdb.ql.ts.TypedData;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.FunctionTools;
using pmdb.ql.ts.DataTypes;

class Neg extends BuiltinFunction {
    public function new() {
        super('__neg__');
    }

/* === Methods === */

    override function apply(args: Array<TypedData>):TypedData {
        return switch args {
            case [DFloat(n)]: DFloat(-n);
            case [DInt(i)]: DInt(-i);
            case [other]:
                throw 'Invalid operation -$other';
            case other:
                throw 'Invalid operation -$other';
        }
    }

    @:keep @fn('Float', 'Float')
    inline function _num(x: Float):Float {
        return -x;
    }

    @:keep @fn('Bool', 'Bool')
    inline function _bool(x: Bool):Bool {
        return !x;
    }
}
