package pmdb.ql.ast.nodes.value;

import pmdb.core.Error;
import pmdb.core.Object;
import pmdb.core.Arch;

import pmdb.ql.ts.DataType;
import pmdb.ql.types.DotPath;

using pmdb.ql.ts.DataTypes;

class ObjectNode extends ValueNode {
    /* Constructor Function */
    public function new(fields, ?expr, ?pos) {
        super(expr, pos);
        this.fields = fields;
    }

/* === Methods === */

    override function eval(ctx: QueryInterp):Dynamic {
        var o:Doc = {};
        for (f in fields) {
            o[f.field] = f.value.eval( ctx );
        }
        return o;
    }

    override function compile() {
        //return ((index: Int) -> ((ctx, args) -> args[index]))( i );
        return (ctx, _) -> eval(ctx);
        //throw 'ass';
    }

    override function clone():ValueNode {
        return new ObjectNode(fields.map(o -> {field:o.field, value:o.value.clone()}));
    }

/* === Fields === */

    var fields: Array<{field:String, value:ValueNode}>;
    //var cfields: Null<Array<{field:String, value:QueryInterp->Array<Dynamic>->Dynamic}>> = null;
}
