package pmdb.flow;

import tannus.ds.HashKey;

import haxe.extern.EitherType;
import haxe.Constraints.Function;

using Slambda;
using tannus.FunctionTools;
using pmdb.ql.types.DataTypes;

class FlowNode <In, Out> {
    /* Constructor Function */
    public function new(nOutputs = 1) {
        //initialize variables
        _nodeId = HashKey.next();
        _nodeLock = 0; // not locked

        _input = new FlowNodeInput( this );
        outputs = [for (i in 0...nOutputs + 1) new FlowNodeOutput(this, i)];
        outputs = [];
        edges = [];
        for (i in 0...nOutputs + 1) {
            outputs[i] = new FlowNodeOutput(this, i);
            edges[i] = [];
        }
    }

/* === Methods === */

    public inline function id():Int {
        return _nodeId;
    }

    public function run() {
        throw new NotImplementedError();
    }

    public inline function connect(node:FlowNode<Out, Dynamic>, slot:Int=0) {
        edges[slot].push(new FlowNodeIoEdge(this, node, slot));
    }

    private function _run_() {
        if (_nodeLock == 0) {
            _nodeLock = 1;
            run();
            _nodeLock = 0;
        }
    }

/* === Properties === */

    public var input(get, never): In;
    private function get_input():In return _input.get();

/* === Variables === */

    private var _nodeId(default, null): Int;
    private var _nodeLock(default, null): Int;

    private var _input(default, null): FlowNodeInput<In>;
    private var outputs(default, null): Array<FlowNodeOutput<Out>>;
    private var edges(default, null): Array<Array<FlowNodeIoEdge<Out>>>;

/* === Static Variables === */
}

@:access(pmdb.flow.FlowNode)
class FlowNodeInput<T> {
    /* Constructor Function */
    public function new(node, ?value) {
        //initialize variables
        this.node = node;
        //this.slot = slot;
        this.value = null;
    }

/* === Instance Methods === */

    public function set(value: T) {
        this.value = value;
    }

    public inline function get():T {
        return this.value;
    }

    public inline function pipe(val: T) {
        set( val );
        flush();
    }

    private inline function flush() {
        node._run_();
    }

/* === Instance Fields === */

    public var node(default, null): FlowNode<T, Dynamic>;
    //public var slot(default, null): Int;

    private var value(default, null): Null<T>;
}

@:access(pmdb.flow.FlowNode)
class FlowNodeOutput<T> {
    /* Constructor Function */
    public function new(node, slot = 0) {
        //initialize variables
        this.node = node;
        this.slot = slot;

        value = null;
    }

/* === Instance Methods === */

    public function set(value: T) {
        this.value = value;
        
        for (link in node.edges[slot]) {
            //link.target.input.pipe( value );
            link.carry();
        }
    }

    public function get():T {
        return this.value;
    }

/* === Instance Fields === */

    public var node(default, null): FlowNode<Dynamic, T>;
    public var slot(default, null): Int;

    private var value(default, null): Null<T>;

    //private var edges(default, null): Array<FlowNodeIoEdge<T>>;
}

@:access(pmdb.flow.FlowNode)
class FlowNodeIoEdge<T> {
    /* Constructor Function */
    public function new(src, out, slot) {
        //initialize variables
        this.source = src;
        this.target = out;
        this.slot = slot;
    }

/* === Instance Methods === */

    public inline function carry() {
        target._input.pipe(source.outputs[slot].get());
    }

/* === Instance Fields === */

    public var source(default, null): FlowNode<T, Dynamic>;
    public var target(default, null): FlowNode<T, Dynamic>;
    public var slot(default, null): Int;
}

class FlowCallbackLink<T> {
    /* Constructor Function */
    public function new(fn) {
        //initialize variables
        this.fn = fn;
        this._disposed = false;
    }

/* === Instance Methods === */

    public inline function dissolve() {
        _disposed = true;
        fn = null;
    }

    public inline function isDisposed():Bool {
        return (_disposed && fn == null);
    }

    public function call(x: T) {
        if (fn != null && !_disposed) {
            fn( x );
        }
    }

/* === Instance Fields === */

    private var fn(default, null): Null<T -> Void>;
    private var _disposed(default, null): Bool;
}

