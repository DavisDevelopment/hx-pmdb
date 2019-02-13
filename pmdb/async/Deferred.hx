package pmdb.async;

import pmdb.core.Error.NotImplementedError;
import pmdb.core.ds.Noise;
import pmdb.core.ds.Outcome;

@:forward
abstract Deferred<Val, Err> (IDeferred<Val, Err>) from IDeferred<Val, Err> to IDeferred<Val, Err> {
/* === Methods === */

    public function isResolved():Bool {
        return this.state.match(Resolved(_));
    }

    public function getResolution():DeferredResolution<Val, Err> {
        return switch ( this.state ) {
            case Resolved(r): r;
            default:
                throw new InvalidOperation('Deferred.getResolution');
        }
    }

    public function hasResult():Bool {
        return this.state.match(Resolved(Result(_)));
    }

    public function hasException():Bool {
        return this.state.match(Resolved(Exception(_)));
    }

    public function sync():Val {
        assert(isResolved(), new InvalidOperation('Deferred.sync'));
        switch (getResolution()) {
            case Result(x):
                return x;

            case Exception(x):
                throw x;
        }
    }

/* === Factories === */

    public static inline function resolution<V,E>(res: DeferredResolution<V, E>):Deferred<V, E> {
        return new SyncDeferred( res );
    }

    public static inline function result<T, E>(v: T):Deferred<T, E> {
        return resolution(Result( v ));
    }
    public static inline function exception<T, E>(e: E):Deferred<T, E> {
        return resolution(Exception( e ));
    }

    @:from
    public static function nilad<T>(m: Void -> T):Deferred<T, Dynamic> {
        return try result(m()) catch (e: Dynamic) exception( e );
    }

    //public static function mAsync<V, E>(exec:(yes:V->Void, nah:E->Void)->Void):Deferred<V, E> {
    @:from
    public static function asyncBase<V, E>(exec:(dv: Deferred<V, E>) -> Void):Deferred<V, E> {
        var out = new AsyncDeferred<V, E>();
        exec( out );
        return out;
    }

    @:from
    public static function monadicAsync<V, E>(exec: (resolve:V->Void)->Void):Deferred<V, E> {
        return asyncBase(function(d: Deferred<V, E>) {
            exec(function(result: V) {
                d.done( result );
            });
        });
    }

    @:from
    public static function dyadicAsync<V, E>(exec: (resolve:V->Void, reject:E->Void)->Void):Deferred<V, E> {
        return asyncBase(function(d: Deferred<V, E>) {
            exec(
                function(result: V) {
                    d.done( result );
                },
                function(except: E) {
                    d.fail( except );
                }
            );
        });
    }
}

class SyncDeferred<V, E> implements IDeferred<V, E> {
    public function new(resolution: DeferredResolution<V, E>):Void {
        this.state = Resolved( resolution );
    }

    public inline function done(x: V) {
        throw new NotImplementedError();
    }

    public inline function fail(x: E) {
        throw new NotImplementedError();
    }

    public inline function handle(fn: Callback<DeferredResolution<V, E>>) {
        fn.invoke(switch state {
            case Resolved(x): x;
            case _: throw new WTFError();
        });
    }

    public var state(default, null): DeferredState<V, E>;
}

class AsyncDeferred<V, E> implements IDeferred<V, E> {
    public function new() {
        state = Pending;
        rs = new Signal();
    }

    public function handle(cb: Callback<DeferredResolution<V, E>>):Void {
        switch ( state ) {
            case Resolved(res):
                cb.invoke( res );

            default:
                assert(rs != null, '[rs] should be populated');
                rs.listen( cb );
        }
    }

    public function done(x: V) {
        assert(!state.match(Resolved(_)), new InvalidOperation('Deferred<*, *> instance is already resolved; cannot resolve again'));

        var res;
        state = Resolved(res=Result( x ));
        rs.broadcast( res );
        rs.dispose();
        rs = null;
    }

    public function fail(x: E) {
        assert(!state.match(Resolved(_)), new InvalidOperation('Deferred<*, *> instance is already resolved; cannot resolve again'));

        var res;
        state = Resolved(res=Exception( x ));
        rs.broadcast( res );
        rs.dispose();
        rs = null;
    }

    //@:noCompletion
    //public var _handler(default, set):(r: DeferredResolution<V, E>)->Void;
    //private function set__handler(hfn) {
        
    //}

    public var state(default, null): DeferredState<V, E>;

    private var rs(default, null): Null<Signal<DeferredResolution<V, E>>> = null;
}

interface IDeferred<Value, Except> {
    var state(default, null): DeferredState<Value, Except>;

    function done(value: Value):Void;
    function fail(error: Except):Void;

    function handle(onResolved: Callback<DeferredResolution<Value, Except>>):Void;

    //@:noCompletion
    //var _handler(default, set): (r: DeferredResolution<Value, Except>)->Void;
}

@:using(pmdb.async.Deferred.DeferredStateTools)
enum DeferredState<A, B> {
    Pending;
    //Running;
    //Waiting<C, D>(link: IDeferred<C, D>);
    Resolved(res: DeferredResolution<A, B>);
}

@:using(pmdb.async.Deferred.DeferredResolutionTools)
enum DeferredResolution<A, B> {
    Result(x: A);
    Exception(x: B);
}

class DeferredResolutionTools {
    public static function toOutcome<V, E>(res: DeferredResolution<V, E>):Outcome<V, E> {
        return switch ( res ) {
            case Result(x): Success(x);
            case Exception(x): Failure(x);
        }
    }

    public static function isResult(r: DeferredResolution<Dynamic, Dynamic>):Bool {
        return r.match(Result(_));
    }

    public static function isException(r: DeferredResolution<Dynamic, Dynamic>):Bool {
        return r.match(Exception(_));
    }

    public static function getResult<T>(r: DeferredResolution<T, Dynamic>):T {
        return switch r {
            case Result(x): x;
            default:
                throw new InvalidOperation('DeferredResolution.getResult');
        }
    }
    public static function getException<T>(r: DeferredResolution<Dynamic, T>):T {
        return switch r {
            case Exception(x): x;
            default:
                throw new InvalidOperation('DeferredResolution.getException');
        }
    }
}

class DeferredStateTools { }
