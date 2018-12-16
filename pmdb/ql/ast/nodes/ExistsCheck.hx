package pmdb.ql.ast.nodes;

import tannus.ds.Lazy;
import tannus.ds.Pair;
import tannus.ds.Set;

import pmdb.ql.ts.DataType;
import pmdb.ql.ts.DocumentSchema;
import pmdb.ql.QueryIndex;
import pmdb.core.Error;
import pmdb.core.Object;
import pmdb.core.Equator;
import pmdb.core.Comparator;
import pmdb.core.Arch;
import pmdb.core.*;
import pmdb.ql.ast.nodes.Check;
import pmdb.ql.ast.nodes.update.*;
import pmdb.ql.ast.nodes.value.*;

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

class ExistsCheck extends Check {
    /* Constructor Function */
    public function new(v:ValueNode, ?e, ?pos) {
        super(e, pos);

        this.value = v;
    }

/* === Methods === */

    override function eval(c: QueryInterp):Bool {
        if ((value is ColumnNode)) {
            return eval_col(cast(value, ColumnNode), c);
        }
        else {
            return (value.eval(c) != null);
        }
    }

    public function eval_col(node:ColumnNode, ctx:QueryInterp):Bool {
        return ctx.document.exists(node.fieldName);
    }

    override function clone():Check {
        return new ExistsCheck(value.clone(), expr, position);
    }

    override function getChildNodes():Array<QueryNode> {
        return [value];
    }

    override function compile() {
        if ((value is ColumnNode)) {
            return ((n:String, c:QueryInterp) -> c.document.exists( n ))
                .curry()
                .applyTo(cast(value, ColumnNode).fieldName);
        }
        else {
            return (function(val:QueryInterp->Dynamic, c:QueryInterp):Bool {
                return !is_nully(val( c ));
            }).curry()
            .applyTo(value.compile());
        }
    }

    private function is_nully(x: Dynamic):Bool {
        return (x == null);
    }

    override function map(fn: QueryNode->QueryNode, deep=false):QueryNode {
        return new ExistsCheck(cast(fn(value), ValueNode), expr, position);
    }

    override function getIndexToUse(store: Store<Dynamic>) {
        if (value.hasLabel('column')) {
            var col = (value.label('column'):String);
            //var tval = (right.label('const') : Dynamic);

            if (store.indexes.exists( col )) {
                return new QueryIndex(store.index(col), ICNone);
            }
        }
        return null;
    }

    override function getExpr() {
        return PredicateExpr.POpExists(value.getExpr());
    }

/* === Variables === */

    public var value(default, null): ValueNode;
}
