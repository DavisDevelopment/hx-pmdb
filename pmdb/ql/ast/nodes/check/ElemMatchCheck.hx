package pmdb.ql.ast.nodes.check;

import pmdb.ql.ts.DataType;
import pmdb.core.Error;
import pmdb.core.Object;
import pmdb.core.Equator;
import pmdb.core.Comparator;
import pmdb.core.Arch;
import pmdb.core.*;
import pmdb.ql.ast.nodes.Check;
import pmdb.ql.QueryIndex;

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

/**
  checks that [right] can be said to contain/include [left]
 **/
class ElemMatchCheck extends Check {
    /* Constructor Function */
    public function new(itr, check, greedy, ?e, ?pos) {
        super(e, pos);

        this.context = itr;
        this.predicate = check;
        this.greedy = greedy;
    }

/* === Methods === */

    /**
      create and return a deep-copy of [this]
     **/
    override function clone():Check {
        return new ElemMatchCheck(
            context.clone(),
            predicate.clone(),
            greedy,
            expr,
            position
        );
    }

    /**
      evaluate [this] Check
     **/
    override function eval(ctx: QueryInterp):Bool {
        final doc = ctx.document;
        var itrv = Arch.makeIterator(context.eval( ctx ));
        if ( greedy ) {
            for (e in itrv) {
                ctx.setDoc(cast e);
                if (!predicate.eval( ctx )) {
                    ctx.setDoc( doc );
                    return false;
                }
            }
            ctx.setDoc( doc );
            return true;
        }
        else {
            for (element in itrv) {
                ctx.setDoc(cast element);
                if (predicate.eval( ctx )) {
                    ctx.setDoc( doc );
                    return true;
                }
            }
            ctx.setDoc( doc );
            return false;
        }
    }

    override function getExpr() {
        return PredicateExpr.POpElemMatch(context.getExpr(), predicate.getExpr(), greedy);
    }

/* === Variables === */

    var context(default, null): ValueNode;
    var predicate(default, null): Check;
    var greedy(default, null): Bool;
}
