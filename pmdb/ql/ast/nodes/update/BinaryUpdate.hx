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

class BinaryUpdate extends Update {
    public function new(left, right, ?expr, ?pos) {
        super(expr, pos);

        this.left = left;
        this.right = right;
    }

/* === Methods === */

    #if !macro
    override function equals(other: QueryNode):Bool {
        return (
            super.equals(other) 
            || 
            (Type.typeof(this).equals(Type.typeof(other))
             && 
             cast(other, BinaryUpdate).with(
                 left.equals(_.left) && right.equals(_.right)
             )
            )
        );
    }
    #end

    override function getChildNodes():Array<QueryNode> {
        return cast [left, right];
    }

    override function eval(ctx: QueryInterp) {
        validate();
        var doc = ctx.newDoc();
        if (doc == null)
            throw new Error('Empty document');
        return apply(ctx, left, right, doc);
    }

    /**
      'apply' [this] node to the given Object
     **/
    public function apply(c:QueryInterp, a:ValueNode, b:ValueNode, doc:Ref<Object<Dynamic>>) {
        return ;
    }

    /**
      check that the given Node is valid as a left-hand node
     **/
    public function isValidLeft(node: ValueNode):Bool {
        return (node != null);
    }

    /**
      check that the given Node is valid as a right-hand node
     **/
    public function isValidRight(node: ValueNode):Bool {
        return (node != null);
    }

    /**
      check that the [left] and [right] nodes are both valid
     **/
    public function validate() {
        if (!isValidLeft( left ))
            throw new Error('Invalid left-node $left');

        if (!isValidRight( right ))
            throw new Error('Invalid right-node $right');
    }

/* === Fields === */

    public var left(default, null): ValueNode;
    public var right(default, null): ValueNode;
}
