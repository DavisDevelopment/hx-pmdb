package pmdb.ql.ast.nodes.update;

import pmdb.ql.ts.DataType;
import pmdb.ql.ast.Value;
import pmdb.ql.ast.PredicateExpr;
import pmdb.ql.ast.UpdateExpr;
import pmdb.ql.ast.nodes.*;
import pmdb.ql.ast.nodes.ValueNode;
import pmdb.core.ds.Ref;
import pmdb.core.Error;
import pmdb.core.Object;
import pmdb.core.Assert.assert;

import haxe.ds.Either;
import haxe.ds.Option;
import haxe.PosInfos;
import haxe.extern.EitherType;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.FunctionTools;
using pmdb.ql.ts.DataTypes;
using pmdb.ql.ast.Predicates;

class UnaryUpdate extends Update {
    public function new(value, ?expr, ?pos) {
        super(expr, pos);

        this.value = value;
    }

/* === Methods === */

    #if !macro @:keep #end
    override function equals(other: QueryNode):Bool {
        return (
            super.equals( other ) ||
            (
             Type.typeof(this).equals(Type.typeof(other)) &&
             cast(other, UnaryUpdate).value.equals( value )
            )
        );
    }

    override function getChildNodes():Array<QueryNode> {
        return cast [value];
    }

    override function eval(ctx: QueryInterp) {
        validate();
        return apply(ctx, value, ctx.newDoc());
    }

    public function apply(c:QueryInterp, value:ValueNode, doc:Ref<Object<Dynamic>>) {
        
    }

    public function validate() {
        assert(value != null, "[value] is undefined");
    }

/* === Variables === */

    public var value(default, null): ValueNode;
}
