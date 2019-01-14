package pmdb.ql.ast.builtins;

import tannus.math.TMath as M;

import pmdb.core.TypedValue;
import pmdb.ql.ast.BuiltinFunction;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.FunctionTools;
using pmdb.ql.ts.DataTypes;

class Sub extends NumericOperator {
    public function new() {
        super('__sub__');
    }

/* === Methods === */

    override function applyNumbers(x:Float, y:Float) {
        return new TypedValue(x - y, TScalar(TDouble));
    }
}
