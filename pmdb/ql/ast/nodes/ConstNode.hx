package pmdb.ql.ast.nodes;

import pmdb.ql.ts.DataType;
import pmdb.core.TypedValue;
import pmdb.ql.ast.Value;

import pmdb.core.Assert.assert;

using pmdb.ql.ts.DataTypes;
using pm.Functions;

class ConstNode extends ValueNode {
    /* Constructor Function */
    public function new(value:Dynamic, ?typed:TypedValue, ?type:DataType, ?expr, ?pos) {
        super(expr, pos);

        this.value = value;
        this.type = type != null ? type : typed != null ? typed.type : value.dataTypeOf();
        this.typed = (typed != null ? typed : value.type());
        if (expr != null && expr.type != null) {
            assert(type.unify(expr.type), 'const ${expr.expr} has been mistyped {$type, ${expr.type}}');
        }

        addLabel('const', value);
    }

/* === Methods === */

    /**
      evaluate [this] node, returning its value
     **/
    override function eval(ctx: QueryInterp):Dynamic {
        return value;
    }

    /**
      'compile' this into a lambda function that doesn't need to access the [this] scope
     **/
    override function compile() {
        final ret:Dynamic = Arch.clone(this.value, CloneMethod.ShallowRecurse);
        return function(c:Dynamic, args:Array<Dynamic>):Dynamic {
            return ret;
        }
    }

    /**
      return a deep clone of [this] node
     **/
    override function clone():ValueNode {
        return new ConstNode(value, typed, expr, position);
    }

    /**
      convert [this] node to an expression
     **/
    override function getExpr():ValueExpr {
        return ValueExpr.make(EConst(CCompiled( typed )));
    }

/* === Variables === */

    public var typed(default, null): TypedValue;
    public var value(default, null): Dynamic;
}
