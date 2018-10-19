package pmdb.core.ds;

interface Collection<T> {
    var key(default, null): Int;
    var size(get, never): Int;

    function free():Void;
    function contains(v: T):Bool;
    function remove(v: T):Bool;
    function iterator():Itr<T>;
    function toArray():Array<T>;
    function isEmpty():Bool;
    //function clone(byRef:Bool=true, copier:T->T=null):Collection<T>;
}
