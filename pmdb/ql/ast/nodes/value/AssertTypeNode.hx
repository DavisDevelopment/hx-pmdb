package pmdb.ql.ast.nodes.value;

import pmdb.core.Error;
import pmdb.core.Object;
import pmdb.core.Arch;

import pmdb.ql.ts.DataType;
import pmdb.ql.ast.nodes.*;

using pmdb.ql.ts.DataTypes;

class AssertTypeNode extends ValueNode {
    /* Constructor Function */
    public function new(value, type, ?expr, ?pos) {
        super(expr, pos);

        this.value = value;
        this.type = type;

        // copy all labels from [value]
        for (lbl in value.labels.keys()) {
            addLabel(lbl, value.labels[lbl]);
        }
    }

/* === Methods === */

    override function eval(ctx: QueryInterp):Dynamic {
        var tmp = value.eval( ctx );
        return
            if (type.checkValue( tmp )) tmp
            else throw new Error();
    }

    override function compile() {
        return value.compile();
    }

    override function clone():ValueNode {
        return new AssertTypeNode(cast value.clone(), type, expr, position);
    }

    override function map(fn:QueryNode->QueryNode, deep:Bool=false):QueryNode {
        return new AssertTypeNode(
            cast(fn(cast value), ValueNode),
            type, expr, position);
    }

/* === Variables === */

    public var value(default, null): ValueNode;
    //public var typeExpr(default, null): TypeExpr;
}
