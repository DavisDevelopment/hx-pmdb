package pmdb.core.query;

import pmdb.core.ds.AVLTree;
import pmdb.core.ds.AVLTree.AVLTreeNode as Leaf;
import pmdb.core.ds.*;
import pmdb.core.Error;
import pmdb.core.Comparator;
import pmdb.core.Equator;
import pmdb.core.Assert.assert;
import pmdb.core.*;

import haxe.ds.Option;

import tannus.math.TMath as M;
import pmdb.Globals.*;
import pmdb.Macros.*;

using Slambda;
using StringTools;
using tannus.ds.StringUtils;
using tannus.FunctionTools;

@:access( pmdb.core.Index )
@:access( pmdb.core.ds.AVLTree )
class IndexCaret <Key, Item> {
    public function new(idx:Index<Key, Item>):Void {
        index = idx;
        node = null;
        reset();
    }

/* === Methods === */

    /**
      method which is called when the iteration is complete
     **/
    public function done():Void {
        close();
    }

    /**
      obtain a reference to the first Node which should be processed
     **/
    function firstNode(t: AVLTree<Key, Item>):Null<Leaf<Key, Item>> {
        return t.root;
    }

    /**
      perform a single discrete iteration 'step'
     **/
    function _step() {
        _pull();

        if (node != null) {
            visitLeaf( node );
        }

        if (node == null) {
            done();
        }
    }

    /**
      initialize [this]
     **/
    public function init() {
        var root = firstNode( index.tree );
        if (root != null)
            route.push( root );
    }

    /**
      perform a single step, and return the operation which should be performed in response to the step
     **/
    public function step():IdxItrOp<Key, Item> {
        _step();

        // if there is no 'loaded' node, then we're done
        if (node == null) {
            return IdxItrOp.IIHalt(null);
        }

        // if there is a node loaded
        else {
            // check whether it should be yielded
            if (shouldYield( node )) {
                // if there are no more nodes queued, we're done
                if (route.isEmpty()) {
                    // return [node] as final
                    return IIHalt( node );
                }
                else {
                    // return [node]
                    return IIYield( node );
                }
            }
            // if the node shan't be yielded
            else {
                if (route.isEmpty()) {
                    return IIHalt(null);
                }
                else {
                    // continue iteration
                    return IIContinue;
                }
            }
        }
    }

    /**
      'visit' a single leaf-node
     **/
    public function visitLeaf(n: Leaf<Key, Item>) {
        left();
        right();
    }

    /**
      check whether the given Node should be 'yield'ed or not
     **/
    public function shouldYield(node: Leaf<Key, Item>):Bool {
        return true;
    }

    /**
      queue up the left node for processing
     **/
    public inline function left() {
        assert(!isClosed(), lazy(new Error('Invalid call to IndexCaret::left. Instance has closed')));
        if (node.left != null)
            route.push( node.left );
    }

    /**
      queue up the right node for processing
     **/
    public inline function right() {
        assert(!isClosed(), lazy(new Error('Invalid call to IndexCaret::left. Instance has closed')));
        if (node.right != null)
            route.push( node.right );
    }

    /**
      queue up both left and right nodes
     **/
    public inline function branch() {
        left();
        right();
    }

    /**
      check whether [this] is closed out
     **/
    public inline function isClosed():Bool {
        return (route.isEmpty() && node == null && _closed);
    }

    /**
      close [this] out for garbage collection
     **/
    public inline function close() {
        node = null;
        route.free();
        _closed = true;
    }

    /**
      'reset' [this] for reiteration
     **/
    public inline function reset() {
        route = new LinkedStack();
        _closed = false;
        //node = firstNode( index.tree );
    }

    /**
      pull next [node] from [route] onto [this]
     **/
    inline function _pull() {
        node = null;
        if (!route.isEmpty()) {
            node = route.pop();
        }
    }

    /**
      iterate over [this]
     **/
    public inline function iterator() {
        return new ICItr( this );
    }

    /**
      create and return a new FunctionalIndexCaret
     **/
    public static inline function make<K, V>(idx:Index<K, V>, ?visit, ?shouldYield, ?firstNode):FunctionalIndexCaret<K, V> {
        return new FunctionalIndexCaret(idx, visit, shouldYield, firstNode);
    }

/* === Properties === */

    public var kc(get, never): Comparator<Key>;
    inline function get_kc():Comparator<Key> return @:privateAccess index._kc;

/* === Variables === */

    public var index(default, null): Index<Key, Item>;

    private var route(default, null): Stack<Leaf<Key, Item>>;
    private var node(default, null): Null<Leaf<Key, Item>>;

    private var _closed(default, null): Bool = false;
}

enum IdxItrOp<K,V> {
    IIYield(node: Leaf<K, V>);
    IIHalt(?node: Leaf<K, V>);
    IIContinue;
}

class ICItr<Key, Item> implements pmdb.core.ds.Itr<IdxItrOp<Key, Item>> {
    var caret(default, null): Null<IndexCaret<Key, Item>>;
    
    public function new(c: IndexCaret<Key, Item>) {
        caret = c;
    }

    public function hasNext() {
        return (caret != null);
    }

    public function next():IdxItrOp<Key, Item> {
        var op = caret.step();
        return switch op {
            case IIHalt(null):
                caret = null;
                op;

            case _:
                op;
        }
    }

    public inline function reset():Itr<IdxItrOp<Key, Item>> {
        throw new NotImplementedError();
    }

    public inline function remove():Void {
        throw new NotImplementedError();
    }
}
