package pmdb.ql.ast.nodes;

import tannus.ds.Lazy;
import tannus.ds.Pair;
import tannus.ds.Set;

import pmdb.ql.ts.DataType;
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

class ValueBinaryOperatorNode extends ValueOperatorNode {
    /* Constructor Function */
    public function new(left, right, op, ?e, ?pos) {
        super(op, e, pos);

        this.left = left;
        this.right = right;
    }

/* === Methods === */

    override function eval(ctx: QueryInterp):Dynamic {
        switch gfn( ctx ) {
            case null:
                throw new Error('No builtin for $op operator');

            case fn:
                return fn.safeApply([left.eval(ctx), right.eval(ctx)]).value;
        }
    }

    override function clone():ValueNode {
        return cast new ValueBinaryOperatorNode(left.clone(), right.clone(), op, expr, position);
    }

    override function compile() {
        if (_fn == null) {
            throw new Error('Betty');
        }
        else {
            final l = left.compile();
            final r = right.compile();
            final dopFn = _fn.toVarArgFunction();
            final opFn = (x, y) -> dopFn(x, y);

            return function(doc:Dynamic, args:Array<Dynamic>):Dynamic {
                return opFn(l(doc, args), r(doc, args));
            }
            //var cfn = (cast _fn.toVarArgFunction() : Dynamic->Dynamic->Dynamic);
            //return (function(cfn, left, right):Dynamic {
                //return ctx -> cfn(left(ctx), right(ctx));
            //})(cfn, left.compile(), right.compile());
        }
    }

    override function opmap(i: QueryInterp) {
        return i.binops;
    }

    override function getChildNodes():Array<QueryNode> {
        return cast [left, right];
    }

/* === Fields === */

    public var left(default, null): ValueNode;
    public var right(default, null): ValueNode;
}
