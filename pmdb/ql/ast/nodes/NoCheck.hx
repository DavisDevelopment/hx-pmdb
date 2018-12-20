package pmdb.ql.ast.nodes;

import pmdb.ql.ast.PredicateExpr as Pe;

class NoCheck extends Check {
    override function clone():Check {
        return new NoCheck(expr, position);
    }

    override function getExpr():Pe {
        return Pe.PNoOp;
    }

    override function eval(i: QueryInterp):Bool {
        return true;
    }

    override function compile():QueryInterp->Bool {
        return (c -> true);
    }
}
