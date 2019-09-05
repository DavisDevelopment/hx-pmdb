package pmdb.ql.ast.nodes.value;

import pmdb.core.Error;
import pmdb.core.Object;
import pmdb.core.Arch;

import pmdb.ql.ts.DataType;

using pmdb.ql.ts.DataTypes;

class ThisNode extends ValueNode {
    /* Constructor Function */
    public function new(?expr, ?pos) {
        super(expr, pos);
    }

/* === Methods === */

    override function eval(ctx: QueryInterp):Dynamic {
        return this.doc( ctx );
    }

    override function compile() {
        //return ((index: Int) -> ((ctx, args) -> args[index]))( i );
        return (ctx, _) -> ctx;
    }

    override function clone():ValueNode {
        return new ThisNode(expr, position);
    }
}
