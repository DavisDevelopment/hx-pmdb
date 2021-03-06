package pmdb.ql.ast.nodes;

import pmdb.ql.ts.DataType;
import pmdb.core.Error;
import pmdb.core.Object;
import pmdb.core.Equator;
import pmdb.core.Comparator;
import pmdb.core.Arch;
import pmdb.core.Store;
import pmdb.ql.QueryIndex;
import pmdb.ql.ast.PredicateExpr;
import pmdb.ql.ast.Value;

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

class EqCheck extends BinaryCheck {
    /* Constructor Function */
    public function new(?eq:Null<Equator<Dynamic>>, l, r, ?e, ?pos):Void {
        super(l, r, e, pos);

        this.equator = eq;
    }

/* === Methods === */

    override function clone():Check {
        return new EqCheck(equator, left, right, expr, position);
    }

    override function map(fn: QueryNode->QueryNode, deep=false):QueryNode {
        return new EqCheck(equator, safeValue(fn(left)), safeValue(fn(right)), expr, position);
    }

    override function eval(ctx: QueryInterp):Bool {
        var l = left.eval( ctx );
        var r = right.eval( ctx );

        if (equator == null) {
            return Arch.areThingsEqual(l, r);
        }
        else {
            return equator.equals(l, r);
        }
    }

    override function getExpr():PredicateExpr {
        return POpEq(left.getExpr(), right.getExpr());
    }

    override function compile():QueryInterp->Bool {
        final l = left.compile(),
              r = right.compile();
        final eq = compileEq();

        return function(ctx: QueryInterp):Bool {
            //return Arch.areThingsEqual(l(ctx), r(ctx));
            return eq(l(ctx.document, ctx.parameters), r(ctx.document, ctx.parameters));
        }
    }

    /**
      compile and return a lambda for the equality comparison
     **/
    function compileEq():Dynamic->Dynamic->Bool {
        return if (equator != null)
            (x, y) -> equator.equals(x, y)
        else __eq;
    }

/* === Variables === */

    public var equator(default, null): Null<Equator<Dynamic>>;
    
    static var __eq = {(x:Dynamic, y:Dynamic) -> Arch.areThingsEqual(x, y);};
}
