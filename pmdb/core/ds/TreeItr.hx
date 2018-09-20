package pmdb.core.ds;

import tannus.ds.Pair;
import haxe.ds.Option;

import pmdb.core.ds.AVLTree;

import tannus.math.TMath as Math;
import Slambda.fn;

using Slambda;
using tannus.ds.ArrayTools;
using tannus.ds.IteratorTools;
using tannus.FunctionTools;
using tannus.async.OptionTools;

@:access(pmdb.core.ds.AVLTree)
class TreeItr <Key, Value> {
    /* Constructor Function */
    public function new(tree: AVLTree<Key, Value>) {
        this.tree = tree;
        this.node = tree.root;
        this.queue = new List();
        this.stopped = false;
    }

/* === Methods === */

    public function isValidNode(node: AVLTreeNode<Key, Value>):Bool {
        return true;
    }

    public function hasNext():Bool {
        if ( stopped ) 
            return false;

        while ( true ) {
            if (node == null && queue.empty())
                return false;

            switch [node.left, node.right] {
                case [null, null]:
                    node = queue.pop();

                case [x, null]|[null, x] if (x != null):
                    node = x;

                case [left, right]:
                    queue.push( right );
                    node = left;
            }

            // ensures that when [hasNext] returns, the next available 'valid' node has been found
            if (!isValidNode( node )) {
                continue;
            }

            //return true;
            break;
        }

        return (node != null);
    }

    public function next():AVLTreeNode<Key, Value> {
        if (node == null) {
            //throw new Error('[@TreeItr]: .next() was called after .hasNext() returned false');
            throw new Error('.next() is not allowed to return null');
        }

        return node;
    }

    public function abort():Void {
        stopped = true;
        return ;
    }

/* === Variables === */

    var tree(default, null): AVLTree<Key, Value>;
    var node(default, null): Null<AVLTreeNode<Key, Value>>;
    var queue(default, null): List<AVLTreeNode<Key, Value>>;
    var stopped(default, null): Bool;
    //var branch(default, null): Null<AVLTreeNode<Key, Value>>;
    //var branch(default, null): AVLTreeNode<Key, Value>;
}
