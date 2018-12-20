package pmdb.ql.ast.nodes;

import pmdb.ql.ts.DataType;
import pmdb.ql.ast.Value;
import pmdb.ql.ast.PredicateExpr;
import pmdb.ql.ast.UpdateExpr;
import pmdb.core.Error;
import pmdb.core.Object;
import pmdb.core.Index;
import pmdb.core.Store;

import pmdb.ql.ast.PredicateExpr as Pe;
import pmdb.ql.ast.Value.ValueExpr as Ve;

import haxe.ds.Either;
import haxe.ds.Option;
import haxe.PosInfos;
import haxe.extern.EitherType;

import pmdb.core.Arch.isType;

using StringTools;
using tannus.ds.StringUtils;
using Slambda;
using tannus.ds.ArrayTools;
using tannus.FunctionTools;
using pmdb.ql.ts.DataTypes;
using pmdb.ql.ast.Predicates;

class Check extends PredicateNode {
    /* Constructor Function */
    public function new(?e, ?pos):Void {
        super(e, pos);
    }

/* === Methods === */

    public function clone():Check {
        return new Check(expr, position);
    }

    public function eval(context: QueryInterp):Bool {
        return true;
    }

    public function compile():QueryInterp -> Bool {
        throw new NotImplementedError(Type.getClassName(mytype()) + '.compile');
    }

    public function optimize():Check {
        return this;
    }

    public inline function getValueNodes():Array<ValueNode> {
        return getNodes(n->isType(n, ValueNode), n->safeNode(n, ValueNode));
    }

    public function getIndexToUse(store: Store<Dynamic>):Null<QueryIndex<Any, Dynamic>> {
        throw new NotImplementedError();
    }

    override function getChildNodes():Array<QueryNode> {
        return null;
    }

    inline function safeValue(node: QueryNode):ValueNode {
        return
            if ((node is ValueNode))
                Std.instance(node, ValueNode)
            else throw new Error('$node is not a ValueNode');
    }

    private inline function mytype():Class<Check> {
        return Type.getClass( this );
    }
}

typedef IdxInfo = {
    type: DataType,
    unique: Bool,
    sparse: Bool
};
