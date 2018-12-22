package pmdb.core.ds.graph;

import pmdb.core.Assert.assert;

/**
  A graph node manages a doubly linked list of WeightedGraphArc objects

  `WeightedGraphNode` objects are created and managed by the `WeightedGraph` class.
 **/
#if generic
@:generic
#end
@:allow(pmdb.core.ds.graph.WeightedGraph)
class WeightedGraphNode<T> {
    /**
      Creates a graph node storing `val`.
     **/
    public function new(value: T):Void {
        val = value;
        arcList = null;
        marked = false;
    }

    public var key(default, null): Int = HashKey.next();

    /* the node's data */
    public var val:T;

    /**
      The node's parent.

      During a BFS/DFS traversal, `parent` points to the previously visited node or to
      itself if the search originated at that node.
     **/
    public var parent:WeightedGraphNode<T>;

    /**
      The traversal depth (distance from the first traversed node).
     **/
    public var depth:Int;

    /**
      A reference to the next graph node in the list.

      The `WeightedGraph` class manages a doubly linked list of `WeightedGraphNode` objects.
     **/
    public var next: WeightedGraphNode<T>;

    /**
      A reference to the previous graph node in the list.

      The `WeightedGraph` class manages a doubly linked list of `WeightedGraphNode` objects.
     **/
    public var prev: WeightedGraphNode<T>;

    /**
      The head of a a doubly linked list of `WeightedGraphArc` objects.
     **/
    public var arcList: WeightedGraphArc<T>;

    /**
      True if the graph node was marked in a DFS/BFS traversal.
     **/
    public var marked: Bool;

    /**
      The total number of outgoing arcs.
     **/
    public var numArcs(default, null):Int = 0;

    private var mWeightedGraph:Null<WeightedGraph<T>> = null;

    /**
      Destroys this object by explicitly nullifying the element and all pointers for GC'ing used resources.

      Improves GC efficiency/performance (optional).
     **/
    public function free() {
        val = cast null;
        next = prev = null;
        arcList = null;
        mWeightedGraph = null;
    }

    /**
      Returns a new *NodeValIterator* object to iterate over the elements stored in all nodes that are connected to this node by an outgoing arc.

      @see http://haxe.org/ref/iterators
     **/
    public function iterator():Itr<T> {
        return new NodeValIterator<T>(this);
    }

    /**
      Returns true if this node is connected to the `target` node.
     **/
    public inline function isConnected(target: WeightedGraphNode<T>):Bool {
        assert(target != null, "target is null");
        return getArc(target) != null;
    }

    /**
      Returns true if this node and the `target` node are pointing to each other.
     **/
    public inline function isMutuallyConnected(target: WeightedGraphNode<T>):Bool {
        assert(target != null, "target is null");
        return getArc(target) != null && target.getArc(this) != null;
    }

    /**
      Finds the arc that is pointing to the `target` node or returns null if such an arc does not exist.
     **/
    public function getArc(target: WeightedGraphNode<T>):WeightedGraphArc<T> {
        assert(target != null, "target is null");
        assert(target != this, "target equals this node");

        var found = false;
        var a = arcList;
        while (a != null) {
            if (a.node == target) {
                found = true;
                break;
            }
            a = a.next;
        }

        if ( found )
            return a;
        else
            return null;
    }

    /**
      Adds an arc pointing from this node to the specified `target` node.
      @param userData custom data stored in the arc (optional). For example `userData` could store a number defining how "hard" it is to get from one node to another.
     **/
    public function addArc(target:WeightedGraphNode<T>, userData:Dynamic = 1):WeightedGraphNode<T> {
        assert(target != this, "target is null");
        assert(getArc(target) == null, "arc to target already exists");
        assert(mWeightedGraph != null, "this node was not added to a graph yet");
        assert(target.mWeightedGraph != null, "target node was not added to a graph yet");
        assert(mWeightedGraph == target.mWeightedGraph, "this node and target node are contained in different graphs");

        var arc =
            if (mWeightedGraph.borrowArc != null)
                mWeightedGraph.borrowArc(target, userData);
            else
                new WeightedGraphArc<T>(target, userData);

        arc.next = arcList;
        if (arcList != null)
            arcList.prev = arc;
        arcList = arc;

        numArcs++;

        return this;
    }

    /**
      Removes the arc that is pointing to the specified `target` node.
      @return true if the arc is successfully removed, false if such an arc does not exist.
     **/
    public function removeArc(target:WeightedGraphNode<T>, mutual:Bool = false):Bool {
        assert(target != this, "target is null");
        assert(mWeightedGraph != null, "this node was not added to a graph yet");
        assert(target.mWeightedGraph != null, "target node was not added to a graph yet");
        assert(mWeightedGraph == target.mWeightedGraph, "this node and target node are contained in different graphs");

        var arc = getArc(target);
        if (arc != null) {
            var other = arc.node;

            if (arc.prev != null)
                arc.prev.next = arc.next;
            if (arc.next != null)
                arc.next.prev = arc.prev;
            if (arcList == arc)
                arcList = arc.next;

            arc.next = null;
            arc.prev = null;
            arc.node = null;

            if (mWeightedGraph.returnArc != null)
                mWeightedGraph.returnArc(arc);

            numArcs--;

            return mutual ? other.removeArc(this) : true;
        }

        return false;
    }

    /**
      Removes all outgoing arcs from this node.
     **/
    public function removeSingleArcs():WeightedGraphNode<T> {
        var arc = arcList;
        while (arc != null) {
            removeArc(arc.node);
            arc = arc.next;
        }
        numArcs = 0;
        return this;
    }

    /**
      Remove all outgoing and incoming arcs from this node.
     **/
    public function removeMutualArcs():WeightedGraphNode<T> {
        var arc = arcList;
        while (arc != null) {
            arc.node.removeArc(this);
            removeArc(arc.node);
            arc = arc.next;
        }
        arcList = null;
        numArcs = 0;
        return this;
    }

    #if !no_tostring
    public function toString():String {
        var t = [], arc;
        if (arcList != null) {
            arc = arcList;
            while (arc != null) {
                t.push(Std.string(arc.val));
                arc = arc.next;
            }
        }

        return
            if (t.length > 0)
                '{ WeightedGraphNode val=$val, arcs=${t.join(",")} }';
            else
                '{ WeightedGraphNode val=$val }';
    }
    #end
}

#if generic
@:generic
#end
class NodeValIterator<T> implements pmdb.core.ds.Itr<T> {
    public function new(node: WeightedGraphNode<T>) {
        mObject = node;
        reset();
    }

    public inline function reset():Itr<T> {
        mArcList = mObject.arcList;
        return this;
    }

    public inline function hasNext():Bool {
        return mArcList != null;
    }

    public inline function next():T {
        var val = mArcList.node.val;
        mArcList = mArcList.next;
        return val;
    }

    public function remove() {
        throw "unsupported operation";
    }

    /* === Fields === */

    var mObject: WeightedGraphNode<T>;
    var mArcList: WeightedGraphArc<T>;
}
