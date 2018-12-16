package pmdb.ql.ast.nodes;

import tannus.ds.Lazy;

import pmdb.core.Error;
import pmdb.core.ValType;

import pmdb.ql.ast.Value;
import pmdb.ql.ts.DataType;

import haxe.PosInfos;
import haxe.ds.Option;

using tannus.FunctionTools;
using tannus.async.OptionTools;
using Slambda;
using tannus.ds.ArrayTools;

/**
  this class represents Nodes which supply values to other Nodes
 **/
class ValueNode extends QueryNode {
    /* Constructor Function */
    public function new(?expr:ValueExpr, ?pos:PosInfos) {
        super( pos );

        this.expr = expr;
        _type = None;//DataType.TMono(null);
    }

    /**
      evaluate [this] ValueNode, and return the result
     **/
    public function eval(i : QueryInterp):Dynamic {
        throw new NotImplementedError();
    }

    public function clone():ValueNode {
        return new ValueNode(expr, position);
    }

    //public inline function ptrCpy(node: ValueNode):ValueNode {
        //return (node == this) ? clone() : node;
    //}

    public function compile():QueryInterp->Dynamic {
        throw new NotImplementedError();
    }

    public function optimize():ValueNode {
        return this;
    }

    /**
      get the equivalent Expression for [this] ValueNode
     **/
    public function getExpr():ValueExpr {
        if (expr != null) {
            return expr;
        }
        else {
            throw new NotImplementedError();
        }
    }

    inline function safeValue(node: QueryNode):ValueNode {
        return
            if ((node is ValueNode))
                Std.instance(node, ValueNode)
            else throw new Error('$node is not a ValueNode');
    }

    public function assignType(type: ValType) {
        _type = Some(type);
    }

    public inline function withType(t: ValType):ValueNode {
        inline assignType( t );
        return this;
    }

    /**
      check whether [this] ValueNode has been "typed"
     **/
    inline public function isTyped():Bool {
        return (_type.isSome() && _type.match(Some(TAny|TNull(TAny))));
    }

/* === Properties === */

    public var type(get, set):Null<DataType>;
    inline function get_type() return _type.getValue();
    inline function set_type(v: Null<DataType>) {
        _type = (v == null)?None:Some(v);
        return v;
    }

/* === Variables === */

    //public var nodeType(default, null): ValueNodeType;

    public var _type(default, null): Option<DataType>;
    public var expr(default, null): Null<ValueExpr>;
}
