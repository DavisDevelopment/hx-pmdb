package pmdb.ql.ast.nodes;

import pmdb.ql.ts.DataType;
import pmdb.ql.ts.TypedData;
import pmdb.core.Error;
import pmdb.core.Object;
import pmdb.core.Equator;
import pmdb.core.Comparator;
import pmdb.core.Arch;

import haxe.ds.Either;
import haxe.ds.Option;
import haxe.PosInfos;
import haxe.extern.EitherType;
import haxe.Constraints.Function;
import haxe.rtti.Meta;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.FunctionTools;
using pmdb.ql.ts.DataTypes;
using pmdb.ql.ast.Predicates;

class ValueUnaryOperatorNode extends ValueOperatorNode {
    /* Constructor Function */
    public function new(value, op, ?e, ?pos) {
        super(op, e, pos);

        this.value = value;
    }

/* === Methods === */

    override function opmap(i: QueryInterp):Map<String, String> {
        return i.unops;
    }

    override function eval(ctx: QueryInterp):Dynamic {
        return switch gfn( ctx ) {
            case null:
                throw new Error('No builtin for $op operator');

            case fn:
                fn.safeApply([value.eval( ctx )]).getUnderlyingValue();
        }
    }

    override function getChildNodes():Array<QueryNode> {
        return cast [value];
    }

/* === Fields === */

    public var value(default, null): ValueNode;
}
