package pmdb.ql.ast.nodes.update;

import hscript.Expr;

import pmdb.ql.ts.DataType;
import pmdb.ql.ast.Value;
import pmdb.ql.ast.PredicateExpr;
import pmdb.ql.ast.UpdateExpr;
import pmdb.ql.ast.nodes.*;
import pmdb.ql.ast.nodes.ValueNode;
import pmdb.ql.ast.nodes.value.*;
import pmdb.core.ds.*;
import pmdb.core.ds.Lazy;
import pmdb.core.ds.Ref;
import pmdb.core.Error;
import pmdb.core.Object;
import pmdb.core.DotPath;

import haxe.ds.Either;
import haxe.ds.Option;
import haxe.PosInfos;
import haxe.extern.EitherType;

using StringTools;
using pmdb.ql.ts.DataTypes;
using pmdb.ql.ast.Predicates;

class PushUpdate extends BinaryUpdate {
    /* Constructor Function */
    public function new(left, right, ?expr, ?pos) {
        super(left, right, expr, pos);
    }

    override function clone():Update {
        return new PushUpdate(left, right, expr, position);
    }

    private function push_onto(list:Dynamic, value:Dynamic) {
        if ((list is Array)) {
            var arr = cast(list, Array<Dynamic>);
            arr.push( value );
            return ;
        }

        throw new Error('$list should be an array');
    }

    override function apply(i:QueryInterp, left:ValueNode, right:ValueNode, doc:Ref<Object<Dynamic>>) {
        inline push_onto(left.eval( i ), right.eval( i ));
    }

    /*
    public inline function column(node: ValueNode):Null<ColumnNode> {
        return
            if ((node is ColumnNode)) cast(node, ColumnNode);
            else null;
    }
    public inline function attracc(node: ValueNode):Null<AttrAccessNode> {
        return
            if ((node is AttrAccessNode)) cast(node, AttrAccessNode);
            else null;
    }
    */

    override function getExpr():UpdateExpr {
        return UPush(left.getExpr(), right.getExpr());
    }
}
