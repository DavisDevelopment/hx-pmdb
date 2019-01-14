package pmdb.ql.ast.builtins;

import tannus.math.TMath as M;

import pmdb.ql.ast.BuiltinFunction;
import pmdb.core.TypedValue;

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

    override function apply(args: Array<TypedValue>):TypedValue {
        return new TypedValue(cast(args[0].value, Float) * -1, TScalar(TDouble));
    }
}
