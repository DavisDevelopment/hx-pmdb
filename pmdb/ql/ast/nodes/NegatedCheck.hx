package pmdb.ql.ast.nodes;

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

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.FunctionTools;
using pmdb.ql.ts.DataTypes;
using pmdb.ql.ast.Predicates;

class NegatedCheck extends Check {
    /* Constructor Function */
    public function new(check:Check, ?e, ?pos):Void {
        super(e, pos);

        this.check = check;
    }

/* === Methods === */

    override function clone():Check {
        return new NegatedCheck(check.clone(), expr, position);
    }

    override function map(fn: QueryNode->QueryNode, deep=false):QueryNode {
        return new NegatedCheck(safeNode(fn(check), Check), expr, position);
    }

    override function eval(ctx: QueryInterp):Bool {
        return !check.eval( ctx );
    }

    override function compile():QueryInterp->Bool {
        return (function(fn, c:QueryInterp):Bool {
            return !fn( c );
        }).bind(check.compile(), _);
    }

    override function getChildNodes():Array<QueryNode> {
        return [check];
    }

    override function equals(o: QueryNode):Bool {
        return (super.equals( o ) || (Arch.isType(o, mytype()) ? cast(o, NegatedCheck).check.equals( check ) : false));
    }

    override function getExpr() {
        return PredicateExpr.POpBoolNot(check.getExpr());
    }

/* === Variables === */

    public var check(default, null): Check;
}
