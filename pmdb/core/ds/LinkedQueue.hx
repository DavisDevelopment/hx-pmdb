package pmdb.core.ds;

using Lambda;

class LinkedQueue<T> implements IQueue<T> {
    public function new(?src: Array<T>) {
        key = HashKey.next();

        if (src != null) {
            mTop = src.length;
            mHead = mTail = getNode(src[0]);
            mHead.next = null;

            for (i in 1...mTop) {
                var node = getNode(src[i]);
                mTail.next = node;
                mTail = node;
            }
        }
    }

/* === Methods === */

    public function peek():T {
        return mHead.value;
    }

    public function back():T {
        return mTail.value;
    }

    public function enqueue(value: T) {
        mTop++;
        var node = getNode( value );
        if (mHead == null) {
            mHead = mTail = node;
            mHead.next = null;
        }
        else {
            mTail.next = node;
            mTail = node;
        }
    }

    /**
      {A, B, C}
      ---
       {B, C}
      ---
        {C}
     **/
    public inline function dequeue():T {
        mTop--;
        var node = mHead;
        if (mHead == mTail) {
            mHead = null;
            mTail = null;
        }
        else {
            mHead = mHead.next;
        }
        return putNode( node );
    }

    public inline function free() {
        while (mTop > 0) {
            dequeue();
        }
    }

    /*
    public inline function dup():LinkedQueue<T> {
        var node = getNode(mHead.value);
        node.next = mHead;
        mHead = node;
        mTop++;
        return this;
    }

    public inline function exchange():LinkedQueue<T> {
        var t = mHead.value;
        mHead.value = mHead.next.value;
        mHead.next.value = t;
        return this;
    }

    public inline function rotRight(n: Int):LinkedQueue<T> {
        var node = mHead;
        for (i in 0...n - 2)
            node = node.next;
        var bot = node.next;
        node.next = bot.next;
        bot.next = mHead;
        mHead = bot;
        return this;
    }

    public inline function rotLeft(n: Int):LinkedStack<T> {
        var top = mHead;
        mHead = mHead.next;
        var node = mHead;
        for (i in 0...n - 2)
            node = node.next;
        top.next = node.next;
        node.next = top;
        return this;
    }

    public function get(i: Int) {
        var node = mHead;
        i = size - i;
        while (--i > 0)
            node = node.next;
        return node.value;
    }

    public function set(i:Int, val:T):LinkedStack<T> {
        var node = mHead;
        i = size - i;
        while (--i > 0)
            node = node.next;
        node.value = val;
        return this;
    }
    */

    /*
    public function swap(i:Int, j:Int) {
        var node = mHead;
        if (i < j) {
            i ^= j;
            j ^= i;
            i ^= j;
        }

        var k = mTop - 1;
        while (k > i) {
            node = node.next;
            k--;
        }
        var a = node;
        while (k > j) {
            node = node.next;
            k--;
        }
        var t = a.value;
        a.value = node.value;
        node.value = t;
        return this;
    }
    */

    /*
    public function copy(i:Int, j:Int):LinkedStack<T> {
        var node = mHead;
        if (i < j) {
            i ^= j;
            j ^= i;
            i ^= j;
        }
        var k = mTop - 1;
        while (k > i) {
            node = node.next;
            k--;
        }
        var val = node.value;
        while (k > j) {
            node = node.next;
            k--;
        }
        node.value = val;
        return this;
    }
    */

    public inline function forEach(fn: T->Int->T):LinkedQueue<T> {
        var node = mHead;
        var i = size;
        while (--i > -1) {
            node.value = fn(node.value, i);
            node = node.next;
        }
        return this;
    }

    public inline function iter(fn: T -> Void):LinkedQueue<T> {
        var node = mHead;
        while (node != null) {
            fn( node.value );
            node = node.next;
        }
        return this;
    }

    public function contains(val: T):Bool {
        var node = mHead;
        while (node != null) {
            if (node.value == val)
                return true;
            node = node.next;
        }
        return false;
    }

    public function remove(val: T):Bool {
        if (isEmpty())
            return false;

        var found = false;
        var node0 = mHead;
        var node1 = mHead.next;

        while (node1 != null) {
            if (node1.value == val) {
                found = true;
                var node2 = node1.next;
                node0.next = node2;
                putNode(node1);
                node1 = node2;
                mTop--;
            }
            else {
                node0 = node1;
                node1 = node1.next;
            }
        }

        if (mHead.value == val) {
            found = true;
            var head1 = mHead.next;
            putNode(mHead);
            mHead = head1;
            mTop--;
        }

        return found;
    }

    public inline function isEmpty():Bool {
        return (mTop == 0);
    }

    public function toList():List<T> {
        var out = new List();
        if (isEmpty())
            return out;
        var node = mHead;
        while (node != null) {
            out.push( node.value );
            node = node.next;
        }
        return out;
    }

    public inline function toVector():haxe.ds.Vector<T> {
        var vec = new haxe.ds.Vector<T>( mTop ), vc = 0;
        if (isEmpty()) return vec;
        var node = mHead;
        while (node != null) {
            vec[vc++] = node.value;
            node = node.next;
        }
        return vec;
    }

    public inline function toArray():Array<T> {
        return toList().array();
    }

    public inline function iterator():Itr<T> {
        return new LinkedQueueIterator<T>( this );
    }

    inline function getNode(x: T) {
        return new LinkedQueueNode<T>( x );
    }

    inline function putNode(node: LinkedQueueNode<T>):T {
        var val = node.value;
        return val;
    }

    inline function removeNode(x: LinkedQueueNode<T>) {
        var n = mHead;
        if (x == n)
            mHead = x.next;
        else {
            while (n.next != x)
                n = n.next;
            n.next = x.next;
        }
        putNode( x );
        mTop--;
    }

    inline function get_size():Int return mTop;

/* === Variables === */

    public var key(default, null): Int;
    public var size(get, never): Int;

    var mHead: Null<LinkedQueueNode<T>> = null;
    var mTail: Null<LinkedQueueNode<T>> = null;
    var mTop: Int = 0;
}

class LinkedQueueNode<T> {
    public var value: T;
    public var next: Null<LinkedQueueNode<T>>;

    public inline function new(x:T) {
        value = x;
    }

    public function toString():String {
        return Std.string(value);
    }
}

@:access(pmdb.core.ds.LinkedQueue)
class LinkedQueueIterator<T> implements Itr<T> {
    var queue: LinkedQueue<T>;
    var walker: LinkedQueueNode<T>;
    var hook: LinkedQueueNode<T>;

    public function new(x: LinkedQueue<T>) {
        queue = x;
        reset();
    }

    public inline function reset():Itr<T> {
        walker = queue.mHead;
        hook = null;
        return this;
    }

    public inline function hasNext():Bool {
        return walker != null;
    }

    public inline function next():T {
        var x = walker.value;
        hook = walker;
        walker = walker.next;
        return x;
    }

    public function remove() {
        queue.removeNode( hook );
    }

    public function free() {
        queue = null;
        walker = null;
        hook = null;
    }
}
