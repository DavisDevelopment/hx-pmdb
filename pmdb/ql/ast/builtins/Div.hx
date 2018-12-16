package pmdb.ql.ast.builtins;

import tannus.math.TMath as M;

import pmdb.ql.ast.BuiltinFunction;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.FunctionTools;
using pmdb.ql.ts.DataTypes;

class Div extends BuiltinFunction {
    public function new() {
        super('__div__');
    }

/* === Methods === */

    @:keep @fn('Float', 'Float', 'Float')
    inline function _num_num(x:Float, y:Float):Float {
        return x / y;
    }
}
