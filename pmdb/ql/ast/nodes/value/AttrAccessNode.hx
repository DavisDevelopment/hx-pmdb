package pmdb.ql.ast.nodes.value;

import pmdb.core.Error;
import pmdb.core.Object;
import pmdb.core.Arch;

import pmdb.ql.ts.DataType;
import pmdb.ql.ts.TypedData;
import pmdb.ql.types.DotPath;

using pmdb.ql.ts.DataTypes;

class AttrAccessNode extends ValueNode {
    /* Constructor Function */
    public function new(o, attr, ?expr, ?pos) {
        super(expr, pos);

        this.o = o;
        this.name = attr;
    }

/* === Methods === */

    override function eval(ctx: QueryInterp):Dynamic {
        return Reflect.field(o.eval( ctx ), name);
    }

    override function compile() {
        //return ((index: Int) -> ((ctx, args) -> args[index]))( i );
        //return (ctx, _) -> ctx;
        final get_o = o.compile();
        return (attr -> (c, args) -> inline Reflect.field(get_o(c, args), attr))(name);
    }

    override function clone():ValueNode {
        return new AttrAccessNode(o.clone(), name, expr, position);
    }

    private var o(default, null): ValueNode;
    private var name(default, null): String;
}
