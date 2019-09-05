package pmdb.ql.ast.nodes;

import pmdb.ql.ts.DataType;
import pmdb.core.Error;
import pmdb.core.Object;

import haxe.ds.Either;
import haxe.ds.Option;
import haxe.PosInfos;
import haxe.extern.EitherType;

using StringTools;
using pm.Strings;
using pm.Arrays;
using pm.Functions;
using pmdb.ql.ts.DataTypes;
using pmdb.ql.ast.Predicates;

class BinaryCheck extends Check {
    /* Constructor Function */
    public function new(left, right, ?e, ?pos):Void {
        super(e, pos);

        this.left = left;
        this.left.orphan();
        attachChild( left );

        this.right = right;
        this.right.orphan();
        attachChild( right );
    }

/* === Methods === */

    override function getChildNodes():Array<QueryNode> {
        return [left, right];
    }

    #if !macro
    override function equals(other: QueryNode):Bool {
        return (
            super.equals(other) 
            || 
            (Type.typeof(this).equals(Type.typeof(other))
             && 
             cast(other, BinaryCheck).with(
                 left.equals(_.left) && right.equals(_.right)
             )
            )
        );
    }
    #end

    override function map(fn: QueryNode -> QueryNode, deep:Bool=false):QueryNode {
        return new BinaryCheck(safeValue(fn(left)), safeValue(fn(right)));
    }

    override function computeTypeInfo() {
        super.computeTypeInfo();
        left.computeTypeInfo();
        right.computeTypeInfo();
    }

/* === Variables === */

    public var left(default, null): ValueNode;
    public var right(default, null): ValueNode;
}

