package pmdb.core.ds;

interface LazyItr<T> {
    function next():LazyItrStep<T>;
}

@:structInit
class LazyItrStep<T> {
    @:optional public var done(default, null): Bool;
    @:optional public var value(default, null): T;
}
