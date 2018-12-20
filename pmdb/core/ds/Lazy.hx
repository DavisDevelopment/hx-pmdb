package pmdb.core.ds;

import pmdb.core.Error;
import haxe.ds.Option;

@:forward
abstract Lazy<T> (ILazy<T>) from ILazy<T> to ILazy<T> {
    @:to
    public inline function get():T {
        return this.get();
    }

    public inline function map<O>(fn: T -> O):Lazy<O> {
        return ofFn(function():O {
            return fn(get());
        });
    }

    public inline function flatMap<O>(fn: T -> Lazy<O>):Lazy<O> {
        return ofFn(function():O {
            return fn(get()).get();
        });
    }

    @:from
    public static inline function ofFn<T>(fn: Void->T):Lazy<T> {
        return inline new FnLazy<T>( fn );
    }

    @:from
    public static inline function ofConst<T>(value: T):Lazy<T> {
        return inline new ConstLazy<T>( value );
    }
}

interface ILazy<T> {
    var disposed(default, null): Bool;
    
    function get():T;
    function dispose():Void;
}

class ConstLazy<T> implements ILazy<T> {
    public function new(value: T):Void {
        //initialize variables
        this.value = value;
        this.disposed = false;
    }

    public inline function get():T {
        #if debug
        if ( disposed ) {
            throw new Error('InvalidAccess: Cannot .get() a Lazy<T> value after .dispose has been called');
        }
        #end

        return value;
    }

    public inline function dispose():Void {
        #if debug
        this.value = null;
        #end

        this.disposed = true;
    }

    public var disposed(default, null): Bool;

    #if debug
    private var value(default, null): Null<T>;
    #else
    private final value: T;
    #end
}

class FnLazy<T> implements ILazy<T> {
    public function new(f: Void->T) {
        this.disposed = false;
        this.value = null;
        this.fn = f;
    }

    public function get():T {
        #if debug
        if ( disposed ) {
            throw new Error('InvalidAccess: Cannot .get() a Lazy<T> value after .dispose has been called');
        }
        #end

        if (fn != null) {
            value = fn();
            fn = null;
        }

        return value;
    }

    public function dispose():Void {
        disposed = true;
        value = null;
        fn = null;
    }

    public var disposed(default, null): Bool;
    private var value(default, null):Null<T>;
    private var fn(default, null):Null<Void -> T>;
}
