package pmdb.ql.ast.nodes;

import pmdb.ql.ts.DataType;
import pmdb.core.Error;
import pmdb.core.Object;
import pmdb.core.Equator;
import pmdb.core.Comparator;
import pmdb.core.Arch;

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

class NInCheck extends InCheck {
    override function eval(ctx: QueryInterp):Bool {
        return !super.eval( ctx );
    }

    override function clone():Check {
        return new NInCheck(equator, left, right, expr, position);
    }

    override function map(fn: QueryNode->QueryNode, deep=false):QueryNode {
        return new NInCheck(equator, safeNode(fn(left), ValueNode), safeNode(fn(right), ValueNode), expr, position);
    }
}
