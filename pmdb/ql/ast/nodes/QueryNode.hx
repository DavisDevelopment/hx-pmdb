package pmdb.ql.ast.nodes;

import pmdb.ql.ts.DataType;
import pmdb.ql.ts.TypeSystemError;
import pmdb.core.Error;
import pmdb.core.Object;
import pmdb.ql.ast.ASTError;

import pmdb.core.Assert.*;
//import pmdb.Macros.*;

import haxe.ds.Either;
import haxe.ds.Option;
import haxe.PosInfos;
import haxe.extern.EitherType;

using StringTools;
using pm.Strings;
using pm.Arrays;
using pmdb.ql.ts.DataTypes;

/**
   class from which all AST-Node classes derive
 **/
class QueryNode {
    /* Constructor Function */
    public function new(?pos: PosInfos):Void {
        this.position = pos;
        this.labels = new Map();
        this.nodeName = Type.getClassName(Type.getClass(this)).afterLast('.');
        if (!nodeName.endsWith('Node')) {
            nodeName = nodeName.replace('Node', '').append('Node');
        }
    }

/* === Methods === */

    /**
      perform some post-instantiation initialization..
      called recursively on all nodes
     **/
    public function init():Void {
        //
    }

    /**
      recursively initialize [this] node and all descendants
     **/
    public inline function initAll():Void {
        iter(n -> n.init(), true);
    }

    /**
      get all child-nodes of [this] node
     **/
    public function getChildNodes():Null<Array<QueryNode>> {
        return null;
    }

    public function getNodes<T>(test:QueryNode->Bool, transform:QueryNode->T):Array<T> {
        return getChildNodes().mapfilter(test, transform);
    }

    /**
      check for conceptual equality between [this] node and [other]
     **/
    public function equals(other: QueryNode):Bool {
        return (this == other);
    }

    /**
      iteratively apply [fn] to [this] node's children
     **/
    public function iter(fn:QueryNode->Void, deep:Bool=false):Void {
        switch [getChildNodes(), deep] {
            case [null, _]:
                return ;

            case [children, _]:
                for (node in children) {
                    fn( node );
                    if ( deep ) {
                        node.iter(fn, deep);
                    }
                }
        }
    }

    /**
      add a label to [this] node, optionally attaching some arbitrary data to it
     **/
    public inline function addLabel(n:String, ?data:Any) {
        labels.set(n, data != null ? data : true);
    }

    /**
      remove a label from [this] node
     **/
    public inline function removeLabel(n: String):Bool {
        return labels.remove( n );
    }

    /**
      check for the presence of a given label on [this] node
     **/
    public inline function hasLabel(n: String):Bool {
        return labels.exists( n );
    }

    /**
      get the value of a label from [this] node
     **/
    public inline function label<T>(n: String):Null<T> {
        return untyped labels[n];
    }

    /**
      computes and initializes typing information on [this] node. 
      This method is called after the Query-tree has been linked with the Interpreter,
      as well as with the Store<?> on which it will be executed.
     **/
    public function computeTypeInfo() {
        ensureInterpLinked( this );
        ensureStoreLinked( this );
    }

    /**
      attach the given interpreter to [this] node
     **/
    public function attachInterp(i: QueryInterp):Void {
        this.interp = i;
    }

    /**
      iteratively attach the given interpreter to the entire node-tree
     **/
    public function attachInterpAll(i: QueryInterp):Void {
        iter(function(node: QueryNode) {
            node.attachInterp( i );
            ensureInterpLinked( node );
        }, true);
    }

    public function setInfo(nn:String, ?info:Array<Dynamic>):QueryNode {
        nodeName = nn;
        if (info != null)
            debugInfo = info;
        return this;
    }

    /**
      attach the given node to [this] one as a child-node
     **/
    public function attachChild(node: QueryNode) {
        node.parentNode = this;
    }

    /**
      unlink [this] node from its parent
     **/
    public function orphan() {
        parentNode = null;
    }

    public function map(fn:QueryNode->QueryNode, recursive:Bool=false):QueryNode {
        if ( recursive ) {
            return fn(map(fn, false));
        }
        else {
            return this;
        }
    }

    /**
      instance-level method to create and return a new instance of the same class
     **/
    public function createSimilar(args: Array<Dynamic>):QueryNode {
        return Type.createInstance(Type.getClass(this), args);
    }

    private inline function safeNode<N:QueryNode>(node:QueryNode, nodeClass:Class<N>):N {
        return Std.is(node, nodeClass) ? 
            Std.instance(node, nodeClass) : 
            throw new Error('$node is not an instance of ' + Type.getClassName(nodeClass));
    }

    private inline function ensureInterpLinked(n: QueryNode) {
        assert(n.interp != null, new QueryExeption(n, Compilation(InterpreterUnlinked)));
    }

    private inline function ensureStoreLinked(n: QueryNode) {
        assert(n.interp.store != null, new QueryExeption(n, Compilation(StoreUnlinked)));
    }

/* === Variables === */

    public var interp(default, null): Null<QueryInterp>;
    public var position(default, null): PosInfos;
    public var labels(default, null): Map<String, Dynamic>;

/* === Debug-Info Variables === */

    public var nodeName(default, null): String;
    public var parentNode(default, null): Null<QueryNode> = null;
    
    //private var subNames(default, null): Null<Array<String>> = null;
    private var debugInfo(default, null): Null<Array<Dynamic>>;
}
