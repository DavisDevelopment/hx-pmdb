package pmdb.core.ds;

interface LazyItr<T> {
    function next():LazyItrStep<T>;
}

@:structInit
class LazyItrStep<T> {
    @:optional public var done(default, null): Bool;
    @:optional public var value(default, null): T;
}

class LazyItrIterator<T> {
    public function new(li: LazyItr<T>):Void {
        lazy = li;
        state = lazy.next();
    }

    public function hasNext() {
        return state == null ? false : !(state.done != null ? state.done : false);
    }

    public function next():T {
        var tmp = state.value;
        state = lazy.next();
        return tmp;
    }

    public var lazy: LazyItr<T>;
    var state: Null<LazyItrStep<T>>;
}
