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

class NEqCheck extends EqCheck {
    override function clone():Check {
        return new NEqCheck(equator, left, right, expr, position);
    }

    override function map(fn: QueryNode->QueryNode, deep=false):QueryNode {
        return new NEqCheck(equator, safeNode(fn(left), ValueNode), safeNode(fn(right), ValueNode), expr, position);
    }

    override function eval(ctx: QueryInterp):Bool {
        return !super.eval( ctx );
    }
}
