package pmdb.ql.ast.nodes;

import pmdb.core.Error;

import pmdb.ql.ast.QlCommand;

class QueryRootNode<TOut> extends QueryNode {
    /* Constructor Function */
    public function new(?e:QlCommand, ?pos) {
        super( pos );
        this.expr = e;
    }

/* === Methods === */

    public function clone():QueryRootNode<TOut> {
        return new QueryRootNode(expr, position);
    }

    public function eval(i: QueryInterp):TOut {
        throw new NotImplementedError();
    }

/* === Fields === */

    public var expr(default, null): Null<QlCommand>;
}
