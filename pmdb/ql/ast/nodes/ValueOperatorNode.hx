package pmdb.ql.ast.nodes;

import pm.Pair;
import pm.Lazy;

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
import haxe.Constraints.Function;
import haxe.rtti.Meta;

using StringTools;
using pm.Strings;
using pm.Arrays;
using pm.Functions;
using pmdb.ql.ts.DataTypes;
using pmdb.ql.ast.Predicates;

class ValueOperatorNode extends ValueNode {
    /* Constructor Function */
    public function new(?e, ?pos) {
        super(e, pos);
    }

    override function eval(i: QueryInterp):Dynamic {
        return null;
    }
}
