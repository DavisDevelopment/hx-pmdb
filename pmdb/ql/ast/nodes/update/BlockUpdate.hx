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
using pm.Functions;
using pmdb.ql.ts.DataTypes;
using pmdb.ql.ast.Predicates;

class BlockUpdate extends Update {
    public function new(?subs, ?e, ?pos) {
        super(e, pos);

        updates = subs != null ? subs : [];
    }

/* === Methods === */

    override function clone():Update {
        return new BlockUpdate(updates.map(x->x.clone()), expr, position);
    }

    override function eval(c: QueryInterp) {
        for (up in updates) {
            up.eval( c );
        }
    }

    override function compile():QueryInterp->Void {
        var children = new Array();
        flatAppend(this, children);
        var changes = children.map(n -> n.compile());
        return function(ctx: QueryInterp) {
            for (ch in changes) {
                ch.call( ctx );
            }
        }
    }

    static function flatAppend(u:Update, a:Array<Update>) {
        if ((u is BlockUpdate)) {
            for (eu in cast(u, BlockUpdate).updates) {
                flatAppend(eu, a);
            }
        }
        else {
            a.push( u );
        }
    }

    override function getExpr():UpdateExpr {
        return UBlock(updates.map(u -> u.getExpr()));
    }

/* === Fields === */

    public var updates(default, null): Array<Update>;
}
