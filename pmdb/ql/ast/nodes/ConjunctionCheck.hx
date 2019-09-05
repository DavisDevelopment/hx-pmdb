package pmdb.ql.ast.nodes;

import pm.Lazy;
import pm.Pair;

import pmdb.core.*;
import pmdb.ql.ts.DataType;
import pmdb.core.Error;
import pmdb.core.Object;
import pmdb.core.Equator;
import pmdb.core.Comparator;
import pmdb.core.Arch;
import pmdb.ql.ast.nodes.Check;

import haxe.ds.Either;
import haxe.ds.Option;
import haxe.PosInfos;
import haxe.extern.EitherType;

using StringTools;
using pm.Strings;
using pm.Arrays;
using pm.Functions;
using pmdb.ql.ts.DataTypes;
using pmdb.ql.ast.Predicates;

class ConjunctionCheck extends Check {
    /* Constructor Function */
    public function new(a:Check, b:Check, ?e, ?pos):Void {
        super(e, pos);

        this.left = a;
        this.right = b;
    }

/* === Methods === */

    override function clone():Check {
        return new ConjunctionCheck(left, right, expr, position);
    }

    override function map(fn: QueryNode->QueryNode, deep=false):QueryNode {
        return new ConjunctionCheck(safeNode(fn(left), Check), safeNode(fn(right), Check), expr, position);
    }

    override function eval(ctx: QueryInterp):Bool {
        return (left.eval( ctx ) && right.eval( ctx ));
    }

    override function compile():QueryInterp->Bool {
        return (function(a, b, c:QueryInterp):Bool {
            return a( c ) && b( c );
        }).bind(left.compile(), right.compile(), _);
    }

    override function getChildNodes():Array<QueryNode> {
        return [left, right];
    }

    override function equals(o: QueryNode):Bool {
        return (super.equals( o ) || (Arch.isType(o, mytype()) ? cast(o, ConjunctionCheck).passTo(c -> c.left.equals(left) && c.right.equals(right)) : false));
    }

    override function getIndexToUse(store: Store<Dynamic>) {
        return switch left.getIndexToUse(store) {
            case null: right.getIndexToUse(store);
            case index: index;
        }
    }

    override function getExpr():PredicateExpr {
        return PredicateExpr.POpBoolAnd(left.getExpr(), right.getExpr());
    }

/* === Variables === */

    public var left(default, null): Check;
    public var right(default, null): Check;
}
