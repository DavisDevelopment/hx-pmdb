package pmdb.core.ds;

import tannus.ds.Ref;
import tannus.ds.Pair;

import pmdb.ql.ast.BoundingValue;
import pmdb.core.ds.AVLTree;

import haxe.ds.Option;

import tannus.math.TMath as Math;
import Slambda.fn;

using Slambda;
using tannus.ds.ArrayTools;
using tannus.ds.IteratorTools;
using tannus.FunctionTools;
using tannus.async.OptionTools;

@:access( pmdb.core.ds.AVLTree )
class AVLTreeCrawler<Key, Val, Prog:AVLTreeCrawlerProgram<Key, Val>> {
    public function new(t, cp) {
        this.tree = t;
        this.node = null;
        this.stack = new LinkedStack();
        this._running = false;

        lnkProgram( cp );
    }

/* === Methods === */

    /**
      method which obtains a reference to the first tree node that will be processed
     **/
    function firstNode():Null<AVLTreeNode<Key, Val>> {
        return tree.root;
    }

    inline function lnkProgram(cp: Prog) {
        program = cp;
        cp.crawler = cast this;
    }

    inline function init() {
        var root = firstNode();
        if (root != null)
            pushNode( root );
        _running = true;
    }

    inline function finalize() {
        _running = false;
        stack.free();
        program.node = null;
    }

    public function step() {
        popState();
        switch (program.step()) {
            case CSContinue:
                if (stack.isEmpty()) {
                    finalize();
                }

            case CSComplete:
                finalize();
        }
    }

    public function loop():Bool {
        if ( _running ) {
            step();
        }
        return _running;
    }

    public function start() {
        init();
        step();
    }

    inline function popState() {
        program.node = node = stack.pop();
    }

    inline function pushNode(n: AVLTreeNode<Key, Val>) {
        stack.push( n );
    }

    public static inline function makeProgram<Key, Val>(fn):AVLTreeCrawlerProgram<Key, Val> {
        return new FunctionalAVLTreeCrawlerProgram( fn );
    }

/* === Fields === */

    public var program(default, null): AVLTreeCrawlerProgram<Key, Val>;

    var stack: Stack<AVLTreeNode<Key, Val>>;
    var node: Null<AVLTreeNode<Key, Val>>;
    var tree: AVLTree<Key, Val>;

    var _running: Bool = false;
}

@:access(pmdb.core.ds.AVLTreeCrawler)
class AVLTreeCrawlerProgramBase<Key, Val> implements AVLTreeCrawlerProgram<Key, Val> {
    public function new() {
        //crawler = c;
        node = null;
    }

/* === Methods === */

    public inline function push(node: AVLTreeNode<Key, Val>) {
        if (node != null)
            crawler.stack.push( node );
    }

    public inline function pop():Null<AVLTreeNode<Key, Val>> {
        return crawler.stack.pop();
    }

    public function step() {
        return CrawlerStep.CSComplete;
    }

    public function abort() {
        //
    }

/* === Fields === */

    public var node: Null<AVLTreeNode<Key, Val>>;
    public var crawler: AVLTreeCrawler<Key, Val, AVLTreeCrawlerProgram<Key, Val>>;
}

class FunctionalAVLTreeCrawlerProgram<K, V> extends AVLTreeCrawlerProgramBase<K, V> {
    public function new(?fn, ?cpm) {
        super();

        if (cpm != null)
            main = cpm;
        else if (fn != null)
            main = new CrawlerProgramMain( fn );
        else
            throw new Error('Function must be provided');
    }

    override function step() {
        return main.step(node, this);
    }

    var main(default, null): CrawlerProgramMain<K, V, FunctionalAVLTreeCrawlerProgram<K, V>>;
}

class CrawlerProgramMain<K, V, Cp:AVLTreeCrawlerProgram<K, V>> implements FAVLTreeCrawlerProgramMain<K, V, Cp> {
    public function new(fn) {
        this._cycle = fn;
    }

    public function step(n:Null<AVLTreeNode<K, V>>, p:Cp):CrawlerStep {
        return _cycle(n, p);
    }

    dynamic function _cycle(n:Null<AVLTreeNode<K, V>>, p:Cp):CrawlerStep {
        return CSComplete;
    }
}

interface AVLTreeCrawlerProgram<K, V> {
    var node: Null<AVLTreeNode<K, V>>;
    var crawler: AVLTreeCrawler<K, V, AVLTreeCrawlerProgram<K, V>>;

    function push(node: AVLTreeNode<K, V>):Void;
    function pop():Null<AVLTreeNode<K, V>>;

    function step():CrawlerStep;
    function abort():Void;
}

interface FAVLTreeCrawlerProgramMain<K, V, Walk:AVLTreeCrawlerProgram<K, V>> {
    function step(node:Null<AVLTreeNode<K, V>>, crawler:Walk):CrawlerStep;
}

enum CrawlerStatus<T> {
    CSWaiting;
    CSRunning;
    CSStopped;
}

enum CrawlerStep {
    CSContinue;
    CSComplete;
}
