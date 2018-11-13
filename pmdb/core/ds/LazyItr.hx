package pmdb.core.ds;

@:forward
abstract LazyItr<T> (LazyIterator<T>) from LazyIterator<T> to LazyIterator<T> {
    @:to
    public inline function iterate():LazyItrIterator<T> {
        return new LazyItrIterator( this );
    }

    @:to
    public inline function iterator():Iterator<T> {
        return cast iterate();
    }
}

interface LazyIterator<T> {
    function next():LazyItrStep<T>;
}

//@:structInit
//class LazyItrStep<T> {
    //@:optional public var done(default, null): Bool;
    //@:optional public var value(default, null): T;
//}
typedef LazyItrStep<T> = {
    ?done: Bool,
    ?value: T
};

class LazyItrIterator<T> {
    public function new(li: LazyItr<T>):Void {
        lazy = li;
        state = lazy.next();
    }

    public inline function hasNext() {
        return state == null ? false : !patchState(state).done;
    }

    public inline function next():T {
        var tmp = state.value;
        state = lazy.next();
        return tmp;
    }

    function patchState(step: LazyItrStep<T>):LazyItrStep<T> {
        if (step.done == null)
            step.done = false;
        return step;
    }

    public var lazy: LazyItr<T>;
    var state: Null<LazyItrStep<T>>;
}
