package pmdb.ql.ast.nodes.update;

import tannus.ds.Lazy;
import tannus.ds.Pair;
import tannus.ds.Set;

import hscript.Expr;

import pmdb.ql.ts.DataType;
import pmdb.ql.ts.DocumentSchema;
import pmdb.ql.ts.DataTypeClass;
import pmdb.ql.ast.Value;
import pmdb.ql.ast.ValueResolver;
import pmdb.ql.ast.PredicateExpr;
import pmdb.ql.ast.UpdateExpr;
import pmdb.ql.ast.nodes.*;
import pmdb.ql.ast.nodes.ValueNode;
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

class NoUpdate extends Update {
    /* Constructor Function */
    public function new(?expr, ?pos) {
        super(expr, pos);
    }

    override function clone():Update {
        return new NoUpdate(expr, position);
    }

    override function eval(c: QueryInterp) {
        //
    }

    override function equals(o: QueryNode):Bool {
        return (this == o || (o != null && (o is NoUpdate)));
    }

    override function getExpr():UpdateExpr {
        return UNoOp;
    }
}
