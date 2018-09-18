package pmdb.core.ds;

import tannus.ds.Pair;
import haxe.ds.Option;

import tannus.math.TMath as Math;
import Slambda.fn;

using Slambda;
using tannus.ds.ArrayTools;
using tannus.ds.IteratorTools;
using tannus.FunctionTools;
using tannus.async.OptionTools;

/**
  
 **/
class AVLTree<Key, Value> {
    /* Constructor Function */
    public function new(?options: AVLTreeOptions<Key, Value>):Void {
        root = null;
        _size = 0;
        unique = options.unique != null ? options.unique : false;

        if (options.model != null) {
            model = options.model;
        }
        else {
            if (options.compareKeys == null) {
                options.compareKeys = (function(x:Key, y:Key):Int {
                    return Reflect.compare(x, y);
                });
            }
            model = TreeModel.create(options.compareKeys, options.checkValueEquality);
        }

        if (options.data != null) {
            for (entry in options.data) {
                insert(entry.key, entry.value);
            }
        }
    }

/* === Instance Methods === */

    /**
      compare two keys to each other
     **/
    function compareKeys(a:Key, b:Key):Int {
        return model.compareKeys(a, b);
    }

    /**
      check for equality between two values
     **/
    function checkValueEquality(a:Value, b:Value):Bool {
        return model.checkValueEquality(a, b);
    }

    /**
      the values between two boundaries
     **/
    public function betweenBounds(?min:BoundingValue<Key>, ?max:BoundingValue<Key>):Array<Value> {
        if (root == null)
            return [];

        return _betweenBounds({
            lower: n2o( min ),
            upper: n2o( max )
        }, root);
    }

    function _betweenBounds(query:{lower:Option<BoundingValue<Key>>, upper:Option<BoundingValue<Key>>}, root:Node<Key, Value>):Array<Value> {
        var nquery = {
            l: obv2bs( query.lower ),
            u: obv2bs( query.upper )
        };
        return _betweenBounds_(nquery, root);
    }

    /**
      recursively acquire node-values for nodes within the given key-range
     **/
    function _betweenBounds_(query:{?l:BoundsSegment<Key>, ?u:BoundsSegment<Key>}, ?lbm:Key->Bool, ?ubm:Key->Bool, root:AVLTreeNode<Key, Value>):Array<Value> {
        var res = [];
        lbm = lbm != null ? lbm : _getLowerBoundMatcher( query.l );
        ubm = ubm != null ? ubm : _getUpperBoundMatcher( query.u );

        if (lbm( root.key ) && root.left != null) {
            Utils.Arrays.append(res, _betweenBounds_(query, lbm, ubm, root.left));
        }
        if (lbm( root.key ) && ubm( root.key )) {
            Utils.Arrays.append(res, root.data);
        }
        if (ubm( root.key ) && root.right != null) {
            Utils.Arrays.append(res, _betweenBounds_(query, lbm, ubm, root.right));
        }

        return res;
    }

    /**
      convert a BoundingValue<T> to a Null<BoundsSegment<T>>
     **/
    inline static function obv2bs<T>(obv: Option<BoundingValue<T>>):Null<BoundsSegment<T>> {
        return (switch obv {
            case None: null;
            case Some(value): switch value {
                case Edge(v): bs(v, false);
                case Inclusive(v): bs(v, true);
            }
        });
    }

    /**
      shorthand method for creating a BoundsSegment
     **/
    inline static function bs<T>(v:T, eq:Bool):BoundsSegment<T> {
        return {v:v, eq:eq};
    }

    /**
      nullable value to an Option<T>
     **/
    inline static function n2o<T>(v: Null<T>):Option<T> {
        return (switch v {
            case null: None;
            case _: Some(v);
        });
    }

    /**
      get a key-tester for the lower-boundary
     **/
    inline function _getLowerBoundMatcher(?q: BoundsSegment<Key>):Key->Bool {
        return 
            if (q != null)
                getLowerBoundMatcher(q.v, q.eq)
            else
                cast _affirmative;
    }

    /**
      get a key-tester for the upper boundary
     **/
    inline function _getUpperBoundMatcher(?q: BoundsSegment<Key>):Key->Bool {
        return 
            if (q != null)
                getUpperBoundMatcher(q.v, q.eq)
            else
                cast _negative;
    }

    @:native('t')
    static function _affirmative<T>(x: T):Bool {
        return true;
    }

    @:native('f')
    static function _negative<T>(x: T):Bool {
        return false;
    }

    /**
      tester for lower boundary key
     **/
    function getLowerBoundMatcher(cutoff:Key, inclusive:Bool=false):Key->Bool {
        return (function(n: Int) {
            return (function(k: Key):Bool {
                return (compareKeys(k, cutoff) > n);
            });
        }(inclusive ? -1 : 0));
    }
    
    /**
      tester for upper boundary key
     **/
    function getUpperBoundMatcher(cutoff:Key, inclusive:Bool=false):Key->Bool {
        return (function(n: Int) {
            return (function(k: Key):Bool {
                return (compareKeys(k, cutoff) < n);
            });
        }(inclusive ? 1 : 0));
    }

    /**
      insert a new node, or reassign the value of an existing one
     **/
    public function insert(key:Key, value:Value) {
        root = _insert(key, value, root);
        ++_size;
    }

    /**
      internal insertion algorithm
     **/
    function _insert(key:Key, value:Value, ?root:AVLTreeNode<Key, Value>):AVLTreeNode<Key, Value> {
        if (root == null)
            return new Node(key, [value]);

        var dif:Int = compareKeys(key, root.key);
        if (dif < 0) {
            root.left = _insert(key, value, root.left);
        }
        else if (dif > 0) {
            root.right = _insert(key, value, root.right);
        }
        else {
            // it's a duplicate, so the insertion failed
            // decrement [size] to account for it
            _size--;
            if ( unique ) {
                throw 'IndexError: Unique-constraint violated';
            }
            else {
                root.data.push( value );
            }
            return root;
        }

        // update height and rebalance tree
        root.height = Math.max(root.leftHeight(), root.rightHeight()) + 1;
        var balanceState:BalanceState = root.getBalanceState();
        
        if (balanceState.equals(UnbalancedLeft)) {
            if (compareKeys(key, root.left.key) < 0) {
                // left left case
                root = root.rotateRight();
            }
            else {
                // left right case
                root.left = root.left.rotateLeft();
                return root.rotateRight();
            }
        }

        if (balanceState.equals(UnbalancedRight)) {
            if (compareKeys(key, root.right.key) > 0) {
                // right right case
                root = root.rotateLeft();
            }
            else {
                // right left case
                root.right = root.right.rotateRight();
                return root.rotateLeft();
            }
        }

        return root;
    }

    /**
      remove a node from [this] tree
     **/
    public function delete(key:Key, ?value:Value):Bool {
        var tmp:Int = _size;
        root = _delete(key, value, root);
        _size--;
        return (tmp != _size);
    }

    /**
      internal deletion algorithm
     **/
    private function _delete(key:Key, value:Null<Value>, root:Null<Node<Key, Value>>):Node<Key, Value> {
        if (root == null) {
            _size++;
            return root;
        }

        // result of comparison of keys
        var dif:Int = compareKeys(key, root.key);

        if (dif < 0) {
            root.left = _delete(key, value, root.left);
        }
        else if (dif > 0) {
            root.right = _delete(key, value, root.right);
        }
        else {
            if (value != null) {
                root.data.remove( value );
                if (root.isEmpty() && root.isLeaf()) {
                    return null;
                }
            }

            // (dif == 0); e.g. <code>key == root.key</code>
            switch ([root.left, root.right]) {
                case [null, null]:
                    root = null;

                case [null, r]:
                    root = r;

                case [l, null]:
                    root = l;

                // neither root.left or root.right are null
                default:
                    var inOrderSuccessor = minValueNode( root.right );
                    root.key = inOrderSuccessor.key;
                    root.data = inOrderSuccessor.data;
                    root.right = _delete(inOrderSuccessor.key, value, root.right);
            }
        }

        // root has been reassigned, check if it's been deleted before moving on
        if (root == null) {
            return root;
        }

        // update height and rebalance tree
        root.height = Math.max(root.leftHeight(), root.rightHeight()) + 1;
        var balanceState = root.getBalanceState();

        if (balanceState.equals(UnbalancedLeft)) {
            if (root.left.getBalanceState().match(Balanced | SlightlyUnbalancedLeft)) {
                return root.rotateRight();
            }
            else if (root.left.getBalanceState().match(SlightlyUnbalancedRight)) {
                root.left = root.left.rotateLeft();
                return root.rotateRight();
            }
        }

        if (balanceState.equals(UnbalancedRight)) {
            switch (root.right.getBalanceState()) {
                case Balanced|SlightlyUnbalancedRight:
                    return root.rotateLeft();

                case SlightlyUnbalancedLeft:
                    root.right = root.right.rotateRight();
                    return root.rotateLeft();

                case _:
                    //
            }
        }

        return root;
    }

    /**
      get the Node<> for [key]
     **/
    public function getNode(key: Key):Option<AVLTreeNode<Key, Value>> {
        if (root == null)
            return None;
        var nnode = _get(key, root);
        return 
            if (nnode == null) Option.None
            else Option.Some(nnode);
    }

    /**
      get the value associated with [key]
     **/
    public function get(key: Key):Null<Array<Value>> {
        return switch getNode(key) {
            case Option.None: null;
            case Option.Some(_.data => data): data;
        }
    }

    /**
      obtain the Node<> for the given [key]
     **/
    private function _get(key:Key, root:Null<Node<Key, Value>>):Null<Node<Key, Value>> {
        var result = this.compareKeys(key, root.key);
        return switch [result, root] {
            case [0, _]: root; 
            case [(_ < 0)=>true, {left: left}]: switch left {
                case null: null;
                default: _get(key, left);
            }

            /**
              same as
            case [(_ > 0)=>true, ...]
             **/
            case [_, {right: r}]: switch r {
                case null: null;
                default: _get(key, r);
            }
            default: null;
        }
    }

    /**
      check whether [key] exists on [this] tree
     **/
    public function contains(key:Key, ?value:Value):Bool {
        if (root == null)
            return false;
        return _contains(key, value, root);
    }

    /**
      internal key-check algorithm
     **/
    private function _contains(key:Key, value:Null<Value>, root:Null<Node<Key, Value>>):Bool {
        if (root == null)
            return false;

        switch ([compareKeys(key, root.key), root]) {
            case [0, _]: 
                return (value == null || root.data.has( value ));

            case [(_ < 0)=>true, {left:l}]: 
               switch l {
                   case null: 
                       return false;

                   default: 
                       return _contains(key, value, l);
               }
            
            case [_, {right:r}]: 
                switch r {
                    case null: 
                        return false;
                    default: 
                        return _contains(key, value, r);
                }
                
            default: 
                return false;
        }
    }

    /**
      execute [f] on every node in [this] tree
     **/
    public function executeOnEveryNode(exec: AVLTreeNode<Key, Value> -> Void) {
        _executeOnEveryNode(root, exec);
    }

    /**
      execute [f] on every node in [this] tree
     **/
    private function _executeOnEveryNode(root:Null<Node<Key, Value>>, f:AVLTreeNode<Key, Value> -> Void) {
        if (root == null)
            return ;

        if (root.left != null)
            _executeOnEveryNode(root.left, f);

        f( root );

        if (root.right != null)
            _executeOnEveryNode(root.right, f);
    }

    public function traverse(f:(tree:AVLTree<Key, Value>, node:AVLTreeNode<Key, Value>)->TraverseStep):TraversalResult {
        if (root == null)
            return Exhausted;
        
        var invokeAfter:Array<Void->Void> = [];
        var finalStep: TraverseStep;
        try {
            finalStep = _traverse(root, f, invokeAfter);
        }
        catch (ti: TraverseInterrupt) {
            switch ti {
                case ThrownStep(x):
                    finalStep = x;
            }
        }

        // map final 'step' returned from traversal to TraversalResult
        inline function last(_s: TraverseStep):TraversalResult {
            return switch _s {
                case Complete: Exhausted; 
                case Halt: Halted; 
                case Exception(e): Failed(e);
                // something wacky has happened; Proceed should never be the value of [finalStep]
                case Proceed: throw 'assert';
                case unex: throw 'Error: Unexpected $unex';
            }
        }

        //
        var result = last(_unwrapStep(finalStep, invokeAfter));

        // handle [invokeAfter]
        for (x in invokeAfter) {
            x();
        }

        return result;
    }

    /*  */
    function _traverse(node:Node<Key, Value>, f:(tree:AVLTree<Key, Value>, node:AVLTreeNode<Key, Value>)->TraverseStep, deferred:Array<Void->Void>):TraverseStep {
        var steps:Array<TraverseStep> = [null, null, null];
        
        steps[1] = _unwrapStep(f(this, node), deferred);
        switch steps[1] {
            case Halt|Exception(_):
                throw TraverseInterrupt.ThrownStep(steps[1]);

            case IgnoreBranch:
                return Complete;

            // it doesn't really make sense for [f] to ever return "Complete", but I can't think of any reason why it should be disallowed
            // will just treat like a Proceed value for now
            case Complete, Proceed:
                // inline local function for handling left/right's steps
                inline function hstep(i:Int, s:TraverseStep) {
                    switch _unwrapStep(s, deferred) {
                        // acceptible values
                        case Complete|Proceed:
                            // okeh

                        /*
                        all other possible values are supposed to be hoisted to the top of the call-stack,
                        and should thus bypass any checks performed by/in [_traverse]
                        */
                        case unex:
                            throw 'AssertionFailed: $unex values should never pass through hstep';
                    }
                    //return true;
                }

                // traverse [node.left]
                if (node.left != null) {
                    hstep(0, steps[0] = _traverse(node.left, f, deferred));
                }

                // traverse [node.right]
                if (node.right != null) {
                    hstep(2, steps[2] = _traverse(node.right, f, deferred));
                }

                return Complete;

            case unex:
                throw 'Error: Unexpected $unex';
        }

        return Exception('wtf');
    }

    /**
      'unwrap' special-case TraverseStep values that have nested TraverseStep's
      (recursively)
     **/
    private static function _unwrapStep(step:TraverseStep, deferred:Array<Void->Void>):TraverseStep {
        return switch step {
            case Defer(f, nested):
                deferred.push( f );
                _unwrapStep(nested, deferred);

            case _: step;
        }
    }

    /**
      iterator for all Nodes
     **/
    public function nodes():Iterator<AVLTreeNode<Key, Value>> {
        return _nodes( root );
    }

    /**
      iterator for all keys
     **/
    public function keys():Iterator<Key> {
        return _mapnodes(root, fn(_.key));
    }

    /**
      iterator for all values
     **/
    public function values():Iterator<Value> {
        return nodes().reduce(function(acc:Array<Value>, node:Node<Key, Value>):Array<Value> {
            return Utils.Arrays.append(acc, node.data);
        }, new Array()).iterator();
    }

    /**
      obtain Iterator<> for traversing [this] Tree
     **/
    function _nodes(root: Node<Key, Value>):Iterator<AVLTreeNode<Key, Value>> {
        return nodeIterLoop(root, []).iterator();
    }

    /**
      obtain iterator which maps Nodes to O values
     **/
    function _mapnodes<O>(root:Node<Key, Value>, f:Node<Key, Value>->O):Iterator<O> {
        return _nodes(root).map( f );
    }

    /**
      recursive method to build an Array of all nodes in the given hierarchy
     **/
    function nodeIterLoop(root:Node<Key, Value>, acc:Array<Node<Key, Value>>):Array<Node<Key, Value>> {
        if (root != null) {
            nodeIterLoop(root.left, acc);
            acc.push( root );
            nodeIterLoop(root.right, acc);
        }
        return acc;
    }

    /**
      the 'minimum' key in [this] tree
     **/
    public function findMinimum():Key {
        return minValueNode(root).key;
    }

    /**
      the 'maximum' key in [this] tree
     **/
    public function findMaximum():Key {
        return maxValueNode(root).key;
    }

    /**
      check [this] tree's size
     **/
    public inline function size():Int {
        return _size;
    }

    /**
      check whether [this] tree is empty
     **/
    public inline function isEmpty():Bool {
        return size() == 0;
    }

    private static function minValueNode<K,V>(node: Node<K, V>):Node<K, V> {
        var current = node;
        while (current.left != null) {
            current = current.left;
        }
        return current;
    }

    private static function maxValueNode<K,V>(node: Node<K, V>):Node<K, V> {
        var current = node;
        while (current.right != null) {
            current = current.right;
        }
        return current;
    }

/* === Instance Fields === */

    public var unique(default, null): Bool;

    // the root node
    private var root(default, null): Null<AVLTreeNode<Key, Value>>;

    private var model(default, null): TreeModel<Key, Value>;

    // the total size of [this] tree
    private var _size(default, null): Int;
}

/**
  represents a node in an AVLTree
 **/
@:allow(pmdb.core.ds.AVLTree)
class AVLTreeNode<Key, T> {
    /* Constructor Function */
    public function new(key, data) {
        this.key = key;
        this.data = data;
        this.left = null;
        this.right = null;
        this.height = 0;
    }

/* === Instance Methods === */

    public inline function isEmpty():Bool {
        return data.empty();
    }

    public inline function isLeaf():Bool {
        return (left == null && right == null);
    }

    public function leftHeight():Int {
        if (left == null)
            return -1;
        return left.height;
    }

    public function rightHeight():Int {
        if (right == null)
            return -1;
        return right.height;
    }

    public function rotateRight():AVLTreeNode<Key, T> {
        var other = left;
        left = other.right;
        other.right = this;
        height = Math.max(leftHeight(), rightHeight()) + 1;
        other.height = Math.max(leftHeight(), height) + 1;
        return other;
    }

    public function rotateLeft():AVLTreeNode<Key, T> {
        var other = right;
        right = other.left;
        other.left = this;
        height = Math.max(leftHeight(), rightHeight()) + 1;
        other.height = Math.max(leftHeight(), height) + 1;
        return other;
    }

    public function getBalanceState():BalanceState {
        var heightDifference = leftHeight() - rightHeight();
        return switch heightDifference {
            case -2: UnbalancedRight;
            case -1: SlightlyUnbalancedRight;
            case 1: SlightlyUnbalancedLeft;
            case 2: UnbalancedLeft;
            default: Balanced;
        }
    }

/* === Instance Fields === */

    public var key(default, null): Key;
    public var data(default, null): Array<T>;

    public var left(default, null): Null<AVLTreeNode<Key, T>>;
    public var right(default, null): Null<AVLTreeNode<Key, T>>;
    public var height(default, null): Null<Int>;
}

private typedef Node<K, V> = AVLTreeNode<K, V>;

enum BalanceState {
    UnbalancedRight;
    SlightlyUnbalancedRight;
    Balanced;
    SlightlyUnbalancedLeft;
    UnbalancedLeft;
}

typedef BoundsSegment<T> = {
    // the value
    v: T,
    // inclusivity
    eq: Bool
}

enum BoundingValue<T> {
    Edge(v: T);
    Inclusive(v: T);
}

//enum WalkStep {
    //Walk;
    //Stop;
//}

enum TraverseStep {
    // 'retur'; marks the end of the traversal when entire hierarchy has been traversed
    Complete;

    // think 'break' expression
    Halt;

    // think 'continue' expression
    Proceed;

    // equivalent to a 'continue' used to jump over the remainder of a routine,
    // used to skip the traversal of a branch/leaf on the tree
    IgnoreBranch;

    // halt traversal and raise [error]
    Exception(error: Dynamic);

    // defer invokation of [f] to immediately following completion of the current traversal-operation
    Defer(f:Void->Void, step:TraverseStep);

    //Ascend(step: TraverseStep);
}

enum TraversalResult {
    // traversal halted prematurely, but didn't fail
    Halted;

    // traversed entire hierarchy; complete now
    Exhausted;

    // failed with [error]
    Failed(error: Dynamic);
}

enum TraverseInterrupt {
    ThrownStep(step: TraverseStep);
}

typedef AVLTreeOptions<K, V> = {
    ?unique: Bool,
    ?compareKeys: K->K->Int,
    ?checkValueEquality: V->V->Bool,
    ?model: TreeModel<K, V>,
    ?data: Array<{key: K, value: V}>
}
