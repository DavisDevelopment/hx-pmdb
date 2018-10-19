package pmdb.core.ds;

using Lambda;

class LinkedStack<T> implements IStack<T> {
    public function new(?src:Array<T>) {
        key = keygen.next();

        if (src != null) {
            var node;
            mTop = src.length;

            for (i in 0...mTop) {
                node = getNode(src[i]);
                node.next = mHead;
                mHead = node;
            }
        }
    }

/* === Methods === */

    public inline function top():T {
        return mHead.value;
    }

    public inline function push(val: T) {
        var node = getNode( val );
        node.next = mHead;
        mHead = node;
        mTop++;
    }

    public inline function pop():T {
        mTop--;
        var node = mHead;
        mHead = node.next;
        return putNode( node );
    }

    public inline function free() {
        while (mTop > 0) {
            pop();
        }
    }

    public inline function dup():LinkedStack<T> {
        var node = getNode(mHead.value);
        node.next = mHead;
        mHead = node;
        mTop++;
        return this;
    }

    public inline function exchange():LinkedStack<T> {
        var t = mHead.value;
        mHead.value = mHead.next.value;
        mHead.next.value = t;
        return this;
    }

    public inline function rotRight(n: Int):LinkedStack<T> {
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

    public inline function forEach(fn: T->Int->T):LinkedStack<T> {
        var node = mHead;
        var i = size;
        while (--i > -1) {
            node.value = fn(node.value, i);
            node = node.next;
        }
        return this;
    }

    public inline function iter(fn: T -> Void):LinkedStack<T> {
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

    public inline function toArray():Array<T> {
        return toList().array();
    }

    public inline function iterator():Itr<T> {
        return new LinkedStackIterator<T>( this );
    }

    inline function getNode(x: T) {
        return new LinkedStackNode<T>( x );
    }

    inline function putNode(node: LinkedStackNode<T>):T {
        var val = node.value;
        return val;
    }

    inline function removeNode(x: LinkedStackNode<T>) {
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

    var mHead: Null<LinkedStackNode<T>> = null;
    var mTop: Int = 0;

    static var keygen = new Incrementer(0);
}

class LinkedStackNode<T> {
    public var value: T;
    public var next: Null<LinkedStackNode<T>>;

    public inline function new(x:T) {
        value = x;
    }

    public function toString():String {
        return Std.string(value);
    }
}

@:access(pmdb.core.ds.LinkedStack)
class LinkedStackIterator<T> implements Itr<T> {
    var stack: LinkedStack<T>;
    var walker: LinkedStackNode<T>;
    var hook: LinkedStackNode<T>;

    public function new(x: LinkedStack<T>) {
        stack = x;
        reset();
    }

    public inline function reset():Itr<T> {
        walker = stack.mHead;
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
        stack.removeNode( hook );
    }

    public function free() {
        stack = null;
        walker = null;
        hook = null;
    }
}
