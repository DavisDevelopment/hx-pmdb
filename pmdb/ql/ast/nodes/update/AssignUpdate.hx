package pmdb.ql.ast.nodes.update;

import pmdb.ql.ts.DataType;
import pmdb.ql.ast.Value;
import pmdb.ql.ast.PredicateExpr;
import pmdb.ql.ast.UpdateExpr;
import pmdb.ql.ast.nodes.*;
import pmdb.ql.ast.nodes.value.*;
import pmdb.ql.ast.nodes.ValueNode;
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

class AssignUpdate extends BinaryUpdate {
    /* Constructor Function */
    public function new(left, right, ?expr, ?pos) {
        super(left, right, expr, pos);
    }

/* === Methods === */

    override function clone():Update {
        return new AssignUpdate(left.clone(), right.clone(), expr, position);
    }

    override function eval(ctx: QueryInterp) {
        left.assign(ctx, right.eval( ctx ));
    }

    //override function apply(i:QueryInterp, left:ValueNode, right:ValueNode, doc:Ref<Object<Dynamic>>) {
        //left.assign(i, right.eval( i ));
    //}

    override function getExpr():UpdateExpr {
        return UAssign(left.getExpr(), right.getExpr());
    }
}
