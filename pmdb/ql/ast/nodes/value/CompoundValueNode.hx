package pmdb.ql.ast.nodes.value;

import tannus.ds.Lazy;

import pmdb.core.Error;

import pmdb.ql.ast.Value;
import pmdb.ql.ts.DataType;

import haxe.PosInfos;
import haxe.ds.Option;

using tannus.FunctionTools;
using tannus.async.OptionTools;
using Slambda;
using tannus.ds.ArrayTools;

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
