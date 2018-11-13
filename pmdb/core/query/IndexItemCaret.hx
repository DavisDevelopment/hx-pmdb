package pmdb.core.query;

import pmdb.core.ds.AVLTree;
import pmdb.core.ds.AVLTree.AVLTreeNode;
import pmdb.core.ds.LazyItr;
import pmdb.core.ds.*;
import pmdb.core.Comparator;
import pmdb.core.Equator;
import pmdb.core.Assert.assert;
import pmdb.core.*;
import pmdb.ql.ts.TypeSystemError;
//import pmdb.core.query.IndexCaret;

import haxe.ds.Option;
import haxe.PosInfos;

import tannus.math.TMath as M;
import pmdb.Globals.*;
import pmdb.Macros.*;

using Slambda;
using tannus.ds.ArrayTools;
using StringTools;
using tannus.ds.StringUtils;
using tannus.FunctionTools;

@:forward
abstract IndexItemCaret<Item> (IndexItemCaretObject<Item>) from IndexItemCaretObject<Item> to IndexItemCaretObject<Item> {
    public static inline function make<T>(i:Index<Any, T>, ?opts:IndexItemCaretInit<T>):FunctionalIndexItemCaret<T> {
        return new FunctionalIndexItemCaret(i, opts);
    }
}

interface IndexItemCaretObject<Item> {
    var index(default, null): Index<Any, Item>;

    function getFirstNode(tree: Tree<Item>):Leaf<Item>;
    function validateLeaf(leaf: Leaf<Item>):Bool;
    function validateItem(item: Item):Bool;
    function visitLeaf(leaf: Leaf<Item>):Void;

    function init():Void;
    function nextLeaf():Null<Leaf<Item>>;
    function nextItem():Null<Item>;
    function isEmpty():Bool;
    function iterator():Iterator<Item>;
    
    function left(l: Leaf<Item>):Void;
    function right(l: Leaf<Item>):Void;
}
class StdIndexItemCaret<Item> implements IndexItemCaretObject<Item> {
    public function new(index: Index<Any, Item>):Void {
        this.index = index;
    }

/* === Methods === */

    public function getFirstNode(tree: Tree<Item>):Leaf<Item> {
        return tree.root;
    }

    public function validateLeaf(leaf: Leaf<Item>):Bool {
        return true;
    }

    public function validateItem(item: Item):Bool {
        return true;
    }

    public function visitLeaf(leaf: Leaf<Item>) {
        push( leaf.left );
        push( leaf.right );
    }

    private function pullState() {
        leaf = branches.pop();
    }

    public function init() {
        push(getFirstNode( index.tree ));
    }

    public function nextLeaf():Null<Leaf<Item>> {
        if (branches.isEmpty()) {
            return null;
        }
        else {
            return branches.pop();
        }
    }

    public function nextItem():Null<Item> {
        if (_items == null) {
            var leaf = nextLeaf();
            if (leaf == null) {
                return null;
            }
            else {
                visitLeaf( leaf );
                if (validateLeaf( leaf )) {
                    _items = leaf.data.filter(x -> validateItem( x ));
                    if (_items.empty()) {
                        _items = null;
                    }
                }
                return nextItem();
            }
        }
        else {
            var ret = _items.shift();
            if (_items.empty()) {
                _items = null;
            }
            return ret;
        }
    }

    public function isEmpty():Bool {
        return (branches.isEmpty() && _items.empty());
    }

    public function iterator():Iterator<Item> {
        return new IndexItemCaretIterator( this );
    }

    public function left(l: Leaf<Item>) {
        push( l.left );
    }

    public function right(l: Leaf<Item>) {
        push( l.right );
    }

    public static function make<T>(i:Index<Any, T>, ?opts:IndexItemCaretInit<T>):FunctionalIndexItemCaret<T> {
        return new FunctionalIndexItemCaret(i, opts);
    }

    inline function push(leaf: Null<Leaf<Item>>) {
        if (leaf != null)
            branches.push( leaf );
    }

/* === Variables === */

    public var index(default, null): Index<Any, Item>;

    private var branches(default, null): Stack<Leaf<Item>> = new LinkedStack();
    private var leaf(default, null): Null<Leaf<Item>> = null;

    private var _items(default, null): Null<Array<Item>> = null;
}

typedef Tree<Item> = AVLTree<Any, Item>;
typedef Leaf<Item> = AVLTreeNode<Any, Item>;

typedef IndexItemCaretExtensionDef<Item> = {
    function getFirstNode(supr:Tree<Item>->Leaf<Item>, tree:Tree<Item>):Leaf<Item>;
    function validateLeaf(supr:Leaf<Item>->Bool, leaf:Leaf<Item>):Bool;
    function validateItem(supr:Item->Bool, item:Item):Bool;
    function visitLeaf(supr:Leaf<Item>->Void, leaf:Leaf<Item>):Void;
    function init(supr:Void->Void):Void;
    function nextLeaf(supr:Void->Null<Leaf<Item>>):Null<Leaf<Item>>;
    function nextItem(supr:Void->Null<Item>):Null<Item>;
    function isEmpty(supr:Void->Bool):Bool;
    function iterator(supr:Void->Iterator<Item>):Iterator<Item>;
}

typedef IndexItemCaretExtensionInit<Item> = {
    @:optional function getFirstNode(supr:Tree<Item>->Leaf<Item>, tree:Tree<Item>):Leaf<Item>;
    @:optional function validateLeaf(supr:Leaf<Item>->Bool, leaf:Leaf<Item>):Bool;
    @:optional function validateItem(supr:Item->Bool, item:Item):Bool;
    @:optional function visitLeaf(supr:Leaf<Item>->Void, leaf:Leaf<Item>):Void;
    @:optional function init(supr:Void->Void):Void;
    @:optional function nextLeaf(supr:Void->Null<Leaf<Item>>):Null<Leaf<Item>>;
    @:optional function nextItem(supr:Void->Null<Item>):Null<Item>;
    @:optional function isEmpty(supr:Void->Bool):Bool;
    @:optional function iterator(supr:Void->Iterator<Item>):Iterator<Item>;
}

class IndexItemCaretExtBase<T> {
    public function new(init: IndexItemCaretExtensionInit<T>):Void {
        getFirstNode = cast function(x, y) {
            throw new Error();
        };
        validateLeaf = cast function(x, y) {
            throw new Error();
        };
        validateItem = cast function(x, y) {
            throw new Error();
        };
        visitLeaf = cast function(x, y) {
            throw new Error();
        };
        init = cast function(f) {
            throw new Error();
        };
        nextLeaf = cast function(f) {
            throw new Error();
        };
        nextItem = cast function(f) {
            throw new Error();
        };
        isEmpty = cast function(f) {
            throw new Error();
        };
        iterator = cast function(f) {
            throw new Error();
        };

        for (m in Reflect.fields(init)) {
            var fn = Reflect.field(init, m);
            if (fn != null) {
                Reflect.setField(this, m, fn);
            }
        }
    }

    public var getFirstNode : (supr:Tree<T>->Leaf<T>, tree:Tree<T>)->Leaf<T>;
    public var validateLeaf : (supr:Leaf<T>->Bool, leaf:Leaf<T>)->Bool;
    public var validateItem : (supr:T->Bool, item:T)->Bool;
    public var visitLeaf : (supr:Leaf<T>->Void, leaf:Leaf<T>)->Void;
    public var init : (supr:Void->Void)->Void;
    public var nextLeaf : (supr:Void->Null<Leaf<T>>)->Null<Leaf<T>>;
    public var nextItem : (supr:Void->Null<T>)->Null<T>;
    public var isEmpty : (supr:Void->Bool)->Bool;
    public var iterator : (supr:Void->Iterator<T>)->Iterator<T>;
}

@:forward
abstract IndexItemCaretExt<T> (IndexItemCaretExtBase<T>) from IndexItemCaretExtBase<T> to IndexItemCaretExtBase<T> {
    @:from
    public static function fromInit1<T>(init: IndexItemCaretExtensionInit<T>):IndexItemCaretExt<T> {
        return new IndexItemCaretExtBase( init );
    }
    @:from
    public static function fromInit2<T, Ext:IndexItemCaretExtensionInit<T>>(init: Ext):IndexItemCaretExt<T> {
        return fromInit1(cast init);
    }
    @:from
    public static function fromInit3<T>(init: IndexItemCaretExtensionDef<T>):IndexItemCaretExt<T> {
        return fromInit1(cast init);
    }
}

class ExtendedIndexItemCaret<T> extends StdIndexItemCaret<T> {
    public function new(_super: IndexItemCaret<T>) {
        super( _super.index );
        this._super = _super;
    }

    override function getFirstNode(tree: Tree<T>):Leaf<T> return _super.getFirstNode(tree);
    override function validateLeaf(leaf: Leaf<T>):Bool return _super.validateLeaf(leaf);
    override function validateItem(item: T):Bool return _super.validateItem( item );
    override function visitLeaf(leaf: Leaf<T>):Void return _super.visitLeaf( leaf );

    override function init():Void {
        super.init();
        _super.init();
    }

    override function nextLeaf():Null<Leaf<T>> return _super.nextLeaf();
    override function nextItem():Null<T> return _super.nextItem();
    override function isEmpty():Bool return _super.isEmpty();
    override function iterator():Iterator<T> return _super.iterator();
    
    override function left(l: Leaf<T>):Void return _super.left( l );
    override function right(l: Leaf<T>):Void return _super.right( l );

    public var _super(default, null): IndexItemCaret<T>;
}

//class WrappedIndexItemCaret<T> extends ExtendedIndexItemCaret<T> {
    //public function new(ii:IndexItemCaret<T>, ext:IndexItemCaretExt<T>) {
        //super( ii );

        //this.ext = ext;
    //}

    //override function getFirstNode(tree: Tree<T>):Leaf<T> return ext.getFirstNode(_super.getFirstNode, tree);
    //override function validateLeaf(leaf: Leaf<T>):Bool return ext.validateLeaf(_super.validateLeaf, leaf);
    //public function validateItem(item: T):Bool return ext.validateItem(_super)

    //public var ext(default, null): IndexItemCaretExt<T>;
//}

class IndexItemCaretIterator<Item> {
    public function new(i) {
        iic = i;
        iic.init();
    }

    /**
      NOTE: this assumes that the only circumstance where [nextItem] returns true is when the iteration is over
     **/
    public function hasNext():Bool {
        return (
            !(iic.isEmpty()) &&
            switch (ensureItem()) {
                case Some(null): false;
                case None: false;
                case _: true;
            }
        );
    }

    public function next():Item {
        var ret;
        switch (ensureItem()) {
            case Some(null):
                throw new Invalid(null, 'Item');

            case None:
                throw new Invalid(None, 'Some(Item)');

            case Some(item):
                ret = item;
                _item = None;
                return ret;
        }
    }

    private inline function ensureItem():Option<Null<Item>> {
        if (_item.equals(None)) {
            _item = Some(iic.nextItem());
        }
        return _item;
    }

    var iic: IndexItemCaret<Item>;
    var _item: Option<Null<Item>> = Option.None;
}

typedef IndexItemCaretInit<T> = {
    ?validateLeaf: (caret:IndexItemCaret<T>, leaf:Leaf<T>) -> Bool,
    ?validateItem: (caret:IndexItemCaret<T>, item:T) -> Bool,
    ?visitLeaf: (caret:IndexItemCaret<T>, leaf:Leaf<T>) -> Void,
    ?getRoot: (caret:IndexItemCaret<T>, tree:Tree<T>) -> Leaf<T>
};
