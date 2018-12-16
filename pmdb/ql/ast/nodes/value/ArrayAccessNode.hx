package pmdb.ql.ast.nodes.value;

import tannus.ds.Lazy;

import pmdb.core.Error;
import pmdb.ql.ts.TypeSystemError;

import pmdb.ql.ast.Value;
import pmdb.ql.ts.DataType;

import haxe.PosInfos;
import haxe.ds.Option;

using tannus.FunctionTools;
using tannus.async.OptionTools;
using Slambda;
using tannus.ds.ArrayTools;

class ArrayAccessNode extends CompoundValueNode {
    /* Constructor Function */
    public function new(array, index, ?expr, ?pos) {
        super([array, index], expr, pos);
    }

/* === Methods === */

    override function eval(ctx: QueryInterp):Dynamic {
        var left = childValues[0].eval( ctx );
        return _getitem_(ctx, left, childValues[1]);
    }

    static function _getitem_(ctx:QueryInterp, array:Dynamic, indx:ValueNode):Dynamic {
        if (Arch.isArray(array)) {
            return cast(array, Array<Dynamic>)[cast(indx.eval(ctx), Int)];
        }
        else {
            throw new Error('$array should be Array<?>');
        }
    }
}
