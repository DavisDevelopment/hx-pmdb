package pmdb.core.ds;

interface Queue<T> extends Collection<T> {
    function enqueue(val: T):Void;
    function dequeue(): T;
    function peek():T;
    function back():T;
}
