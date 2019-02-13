package pmdb.core.ds;

interface IQueue<T> {
    function enqueue(val: T):Void;
    function dequeue(): T;
    function peek():T;
    function back():T;

    var key(default, null): Int;
    var size(get, never): Int;

    function free():Void;
    function contains(v: T):Bool;
    function remove(v: T):Bool;
    function iterator():Itr<T>;
    function toArray():Array<T>;
    function isEmpty():Bool;
}
