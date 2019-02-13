package pmdb.async;

import pmdb.core.ds.HashKey;

class CallbackHandle<T> {
    public inline function new(cb: T -> Void):Void {
        fn = cb;
    }

    public function call(x: T) {
        if ( rem ) {
            throw new InvalidOperation('CallbackInvokation', 'callback has been deallocated');
        }

        assert(Arch.isFunction( fn ), new Error('InvalidCallbackError'));
        fn( x );
    }

    public inline function dispose():Bool {
        fn = null;
        return rem = true;
    }

    public inline function isDisposed():Bool {return rem;}

    public var key(default, null):Int = HashKey.next();

    private var rem(default, null):Bool = false;
    private var fn(default, null): Null<T -> Void> = null;
}
