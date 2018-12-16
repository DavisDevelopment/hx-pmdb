package pmdb.ql.ast.nodes;

import pmdb.ql.ts.DataType;
import pmdb.ql.ts.TypedData;
import pmdb.ql.ast.Value;

using pmdb.ql.ts.DataTypes;
using tannus.FunctionTools;

class ConstNode extends ValueNode {
    /* Constructor Function */
    public function new(value:Dynamic, ?typed:TypedData, ?expr, ?pos) {
        super(expr, pos);

        this.value = value;
        this.type = value.dataTypeOf();
        this.typed = (typed != null ? typed : value.typed());

        addLabel('const', value);
    }

/* === Methods === */

    override function eval(ctx: QueryInterp):Dynamic {
        return value;
    }

    override function compile() {
        return ((v: Dynamic) -> ((_ -> v):QueryInterp->Dynamic))(value);
    }

    override function clone():ValueNode {
        return new ConstNode(value, typed, expr, position);
    }

    override function getExpr():ValueExpr {
        return ValueExpr.EConst(CCompiled(typed));
    }

/* === Variables === */

    public var typed(default, null): TypedData;
    public var value(default, null): Dynamic;
}
