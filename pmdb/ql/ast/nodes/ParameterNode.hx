package pmdb.ql.ast.nodes;

import pmdb.core.Error;
import pmdb.core.Object;
import pmdb.core.Arch;

import pmdb.ql.ts.DataType;
import pmdb.ql.types.DotPath;

using pmdb.ql.ts.DataTypes;

class ParameterNode extends ValueNode {
    /* Constructor Function */
    public function new(id:Int, ?expr, ?pos) {
        super(expr, pos);

        this.i = id;
    }

/* === Methods === */

    override function eval(ctx: QueryInterp):Dynamic {
        return ctx.parameters[i];
    }

    override function compile() {
        return ((index: Int) -> ((ctx, args) -> args[index]))( i );
    }

    override function clone():ValueNode {
        return new ParameterNode(i, expr, position);
    }

/* === Variables === */

    public var i(default, null): Int;
}
