package pmdb.ql.ast.nodes.value;

import pm.Lazy;

import pmdb.core.Error;

import pmdb.ql.ast.Value;
import pmdb.ql.ts.DataType;

import haxe.PosInfos;
import haxe.ds.Option;

using pm.Functions;
using pm.Options;
using pm.Arrays;

class CompoundValueNode extends ValueNode {
    /* Constructor Function */
    public function new(values:Array<ValueNode>, ?expr, ?pos) {
        super(expr, pos);

        childValues = values.copy();
    }

    override function computeTypeInfo() {
        super.computeTypeInfo();
        for (node in childValues)
            node.computeTypeInfo();
    }

    override function getChildNodes():Array<QueryNode> {
        return cast childValues;
    }

    public var childValues(default, null): Array<ValueNode>;
}
