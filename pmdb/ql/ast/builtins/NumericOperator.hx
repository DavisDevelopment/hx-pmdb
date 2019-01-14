package pmdb.ql.ast.builtins;

import tannus.math.TMath as M;

import pmdb.ql.ast.BuiltinFunction;
import pmdb.core.Error;
import pmdb.core.TypedValue;
import pmdb.ql.ts.DataType;
import pmdb.ql.ts.TypeSystemError;

using pmdb.core.Arch;
using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.FunctionTools;
using pmdb.ql.ts.DataTypes;

class NumericOperator extends BuiltinFunction {
    public function new(name) {
        super( name );
    }

/* === Methods === */

    override function apply(args: Array<TypedValue>):TypedValue {
        switch ( args ) {
            case [{value:(_ == null) => true}, _], [{value:(_ == null) => true}]: 
                throw new InvalidOperation('operator with Null operands not supported');

            case [{type:TScalar(TInteger|TDouble), value:cast(_, Float) => x}, {value:y}]:
                assert(y.isFloat(), new TypeError(y, TScalar(TDouble)));
                return applyNumbers(x, cast(y, Float));

            //case [{type:TScalar(TString), value:cast(_, String)=>s}, {value:v}], [{value:v}, {type:TScalar(TString), value:cast(_, String)=>s}]:
                //return new TypedValue(s + v, TScalar(TString));

            case [x, y]:
                throw new InvalidOperation('$x + $y');

            case many:
                return many.reduceInit(function(a:TypedValue, b:TypedValue) {
                    return #if macro apply([a, b]); #else call(a, b); #end
                });
        }
    }

    function applyNumbers(x:Float, y:Float):TypedValue {
        return new TypedValue(x + y, TScalar(TDouble));
    }
}
