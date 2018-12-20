package pmdb.core.query;

import pmdb.core.ds.AVLTree;
import pmdb.core.ds.AVLTree.AVLTreeNode as Leaf;
import pmdb.core.ds.*;
import pmdb.core.Comparator;
import pmdb.core.Equator;
import pmdb.core.Assert.assert;
import pmdb.core.*;
import pmdb.core.query.IndexCaret;

import haxe.ds.Option;

import tannus.math.TMath as M;
import pmdb.Globals.*;
import pmdb.Macros.*;

using Slambda;
using StringTools;
using tannus.ds.StringUtils;
using tannus.FunctionTools;

class FunctionalIndexCaret<Key, Item> extends IndexCaret<Key, Item> {
    /* Constructor Function */
    public function new(idx, ?visitLeaf, ?shouldYield, ?firstNode) {
        super(idx);

        if (visitLeaf != null)
            visit = visitLeaf;
        if (shouldYield != null)
            yieldPredicate = shouldYield;
        if (firstNode != null)
            root = firstNode;
    }

/* === Methods === */

    public dynamic function yieldPredicate(self:IndexCaret<Key, Item>, node:Leaf<Key, Item>):Bool {
        return true;
    }

    public dynamic function root(self:IndexCaret<Key, Item>, tree:AVLTree<Key, Item>):Leaf<Key, Item> {
        return superFirstNode( tree );
    }

    private function superFirstNode(tree: AVLTree<Key, Item>):Leaf<Key, Item> {
        return super.firstNode( tree );
    }

    override function firstNode(tree) {
        return root(this, tree);
    }

    override function shouldYield(node) {
        return yieldPredicate(this, node);
    }

    public dynamic function visit(self:IndexCaret<Key, Item>, node:Leaf<Key, Item>):Void {
        return ;
    }

    override function visitLeaf(node: Leaf<Key, Item>):Void {
        return visit(this, node);
    }

/* === Fields === */

    public var _yieldPredicate: IndexCaret<Key, Item> -> Leaf<Key, Item> -> Bool;
    public var _: Type;
}
