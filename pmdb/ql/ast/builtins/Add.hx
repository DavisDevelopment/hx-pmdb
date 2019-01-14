package pmdb.ql.ast.builtins;

import tannus.math.TMath as M;

import pmdb.ql.ast.BuiltinFunction;
import pmdb.core.Error;
import pmdb.core.TypedValue;
import pmdb.ql.ts.TypeSystemError;

using pmdb.core.Arch;
using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.FunctionTools;
using pmdb.ql.ts.DataTypes;

class Add extends NumericOperator {
    public function new() {
        super('__add__');
    }

/* === Methods === */

    override function apply(args: Array<TypedValue>):TypedValue {
        switch ( args ) {
            case [{type:TScalar(TString), value:cast(_, String)=>s}, {value:v}], [{value:v}, {type:TScalar(TString), value:cast(_, String)=>s}]:
                return new TypedValue(s + v, TScalar(TString));

            default:
                return super.apply( args );
        }
    }
}
