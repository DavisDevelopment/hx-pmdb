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

/**
  checks that the [left] value can be said to 'contain' or 'include' the [right] value
 **/
class ContainsCheck extends InCheck {
    /* Constructor Function */
    public function new(?eq:Equator<Dynamic>, left, right, ?expr, ?pos) {
        super(eq, left, right, expr, pos);
    }

/* === Methods === */

    override function eval(ctx: QueryInterp):Bool {
        return swappedEval( ctx );
    }

    private function swappedEval(ctx: QueryInterp):Bool {
        var l = this.left, r = this.right;
        try {
            this.left = r;
            this.right = l;
            var res = super.eval( ctx );
            this.left = l;
            this.right = r;
            return res;
        }
        catch (err: Dynamic) {
            this.left = l;
            this.right = r;
            throw err;
        }
    }

    override function map(fn: QueryNode->QueryNode, deep=false):QueryNode {
        return new ContainsCheck(equator, safeValue(fn(left)), safeValue(fn(right)), expr, position);
    }
}
