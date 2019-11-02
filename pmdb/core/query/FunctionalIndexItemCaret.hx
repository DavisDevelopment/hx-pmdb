package pmdb.core.query;

import pmdb.core.ds.AVLTree;
import pmdb.core.ds.*;
import pmdb.core.Comparator;
import pmdb.core.Equator;
import pmdb.core.Assert.assert;
import pmdb.core.*;
import pmdb.core.query.IndexItemCaret;

import haxe.ds.Option;

import pmdb.Globals.*;
import pmdb.Macros.*;

using Slambda;
using StringTools;

class FunctionalIndexItemCaret<Item> extends StdIndexItemCaret<Item> {
    /* Constructor Function */
    public function new(idx, ?options:IndexItemCaretInit<Item>) {
        super( idx );

        if (options != null) {
            var o = options;
            if (o.getRoot != null)
                null;
            if (o.validateItem != null)
                shouldYield = o.validateItem;
            if (o.validateLeaf != null)
                shouldProcess = o.validateLeaf;
            if (o.visitLeaf != null)
                visit = o.visitLeaf;
        }
    }

/* === Methods === */

    //public dynamic function visit(self:IndexItemCaret<Item>, item:Item):Void {
        //return ;
    //}

    public dynamic function shouldProcess(self:IndexItemCaret<Item>, leaf:Leaf<Item>):Bool {
        return superValidateLeaf( leaf );
    }

    public dynamic function shouldYield(self:IndexItemCaret<Item>, item:Item):Bool {
        return superValidateItem( item );
    }

    public dynamic function visit(self:IndexItemCaret<Item>, leaf:Leaf<Item>) {
        superVisitLeaf( leaf );
    }

    override function visitLeaf(leaf: Leaf<Item>) {
        visit(this, leaf);
    }

    private function superVisitLeaf(leaf: Leaf<Item>) {
        super.visitLeaf( leaf );
    }

    private function superValidateLeaf(leaf: Leaf<Item>):Bool {
        return super.validateLeaf( leaf );
    }

    private function superValidateItem(item: Item):Bool {
        return super.validateItem( item );
    }

    override function validateItem(item: Item):Bool {
        return shouldYield(this, item);
    }

    override function validateLeaf(leaf: Leaf<Item>):Bool {
        return shouldProcess(this, leaf);
    }
}

