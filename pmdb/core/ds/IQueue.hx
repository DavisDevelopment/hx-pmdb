package pmdb.core.ds;

interface IQueue<T> extends Collection<T> {
    function enqueue(val: T):Void;
    function dequeue(): T;
    function peek():T;
    function back():T;
}
