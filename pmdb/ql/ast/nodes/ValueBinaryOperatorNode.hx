package pmdb.ql.ast.nodes;

import pm.Pair;
import pm.Lazy;

import pmdb.ql.ts.DataType;
import pmdb.core.Error;
import pmdb.core.Object;
import pmdb.core.Equator;
import pmdb.core.Comparator;
import pmdb.core.Arch;
import pmdb.runtime.Operator;

import haxe.ds.Either;
import haxe.ds.Option;
import haxe.PosInfos;
import haxe.extern.EitherType;
import haxe.Constraints.Function;
import haxe.rtti.Meta;

using StringTools;
using pm.Functions;
using pmdb.ql.ts.DataTypes;
using pmdb.ql.ast.Predicates;

class ValueBinaryOperatorNode extends ValueOperatorNode {
    /* Constructor Function */
    public function new(left, right, op, ?e, ?pos) {
        super(e, pos);

        this.left = left;
        this.right = right;
        this.op = op;
    }

/* === Methods === */

    override function eval(ctx: QueryInterp):Dynamic {
        return op.f(left.eval(ctx), right.eval(ctx));
    }

    override function clone():ValueNode {
        return cast new ValueBinaryOperatorNode(left.clone(), right.clone(), op, expr, position);
    }

    override function compile() {
        final l = left.compile();
        final r = right.compile();
        final opFn = (x, y) -> op.f(x, y);

        return function(doc:Dynamic, args:Array<Dynamic>):Dynamic {
            return opFn(l(doc, args), r(doc, args));
        }
    }

    override function getChildNodes():Array<QueryNode> {
        return cast [left, right];
    }

/* === Fields === */

    public var left(default, null): ValueNode;
    public var right(default, null): ValueNode;

    public var op(default, null):BinaryOperator<Dynamic, Dynamic, Dynamic>;
}
