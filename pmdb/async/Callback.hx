package pmdb.async;

import pmdb.core.ds.Noise;

abstract Callback<T> (T -> Void) from (T -> Void) {
    /* Constructor Function */
    public inline function new(fn) {
        this = fn;
    }

    @:to
    inline function toFunction():T->Void return this;

    static var depth = 0;
    static inline var MAX_DEPTH = #if (interp && !eval) 100 #elseif python 200 #else 1000 #end;

    /**
      call [this] callback
     **/
    public function invoke(data: T):Void {
        if (depth < MAX_DEPTH) {
            depth++;
            //TODO: consider handling exceptions here (per opt-in?) to avoid a failing callback from taking down the whole app
            (this)(data);
            depth--;
        }
        else {
            Callback.defer(invoke.bind( data ));
        }
    }

    /**
      Seems useful, though most likely isn't
     **/
    @:to 
    @:deprecated('Implicit cast from Callback<Noise> is deprecated. Please create an issue if you find it useful, and don\'t want this cast removed.')
    static function ignore<T>(cb: Callback<Noise>):Callback<T> {
        return function (_) cb.invoke(Noise);
    }

    @:from 
    //inlining this seems to cause recursive implicit casts
    static function fromNiladic<A>(f: Void->Void):Callback<A> {
        return #if js cast f #else function (_) f() #end;
    }

    @:from 
    static function fromMany<A>(callbacks:Array<Callback<A>>):Callback<A> {
        return function (v: A) {
            for (callback in callbacks)
                callback.invoke( v );
        }
    }

    @:noUsing 
    static public inline function defer(fn: Void->Void):Void {
        #if macro
            fn();
        #elseif tink_runloop
            tink.RunLoop.current.work( fn );
        #elseif hxnodejs
            js.Node.process.nextTick( fn );
        #elseif luxe
            Luxe.timer.schedule(0, fn);
        #elseif snow
            snow.api.Timer.delay(0, fn);
        #elseif java
            //TODO: find something that leverages the platform better
            haxe.Timer.delay(fn, 1);
        #elseif ((haxe_ver >= 3.3) || js || flash || openfl)
            haxe.Timer.delay(fn, 0);
        #else
            f();
        #end
    }
}

private interface LinkObject {
    function cancel():Void;
}


abstract CallbackLink(LinkObject) from LinkObject {
    inline function new(link: Void->Void) {
        this = new SimpleLink( link );
    }

    public inline function cancel():Void {
        if (this != null) {
            this.cancel();
        }
    }

    //@:deprecated('Use cancel() instead')
    public inline function dissolve():Void {
        cancel();
    }

    static function noop() {}

    @:to inline function toFunction():Void->Void {
        return if (this == null) noop else this.cancel;
    }

    @:to inline function toCallback<A>():Callback<A> {
                                         return function (_) this.cancel();
    }

    @:from static inline function fromFunction(fn: Void->Void) {
        return new CallbackLink( fn );
    }

    @:op(a & b)
    static public inline function join(a:CallbackLink, b:CallbackLink):CallbackLink {
        return new LinkPair(a, b);
    }

    @:from 
    static public function fromMany(callbacks:Array<CallbackLink>) {
        return fromFunction(function () for (cb in callbacks) cb.cancel());
    }
}

private class SimpleLink implements LinkObject {
    var fn: Void->Void;
    public inline function new(f) {
        fn = f;
    }

    public inline function cancel() {
        if (fn != null) {
            fn();
            fn = null;
        }
    }
}

private class LinkPair implements LinkObject {
    var a:CallbackLink;
    var b:CallbackLink;
    var dissolved:Bool = false;

    public inline function new(a, b) {
        this.a = a;
        this.b = b;
    }

    public function cancel() {
        if ( !dissolved ) {
            dissolved = true;
            a.cancel();
            b.cancel();
            a = null;
            b = null;
        }
    }
}

private class ListCell<T> implements LinkObject {
    private var list: Array<ListCell<T>>;
    private var cb: Callback<T>;

    public function new(cb, list) {
        if (cb == null) 
            throw new TypeErrorLike(null, 'Callback');
        this.cb = cb;
        this.list = list;
    }

    public inline function invoke(data) {
        if (cb != null) 
            cb.invoke( data );
    }

    public function clear() {
        list = null;
        cb = null;
    }

    public function cancel() {
        switch list {
            case null:
                //
            case v:
                clear();
                v.remove( this );
        }
    }
}

/**
  abstract utility type
 **/
abstract CallbackList<T> (Array<ListCell<T>>) from Array<ListCell<T>> {

    inline public function new():Void {
        this = [];
    }

    public var length(get, never):Int;
    private inline function get_length():Int return this.length;  

    @:arrayAccess
    public function get(index: Int):ListCell<T> {
        assert((index >= 0 && index < length && Math.isFinite( index )), haxe.io.Error.OutsideBounds);

        return this[index];
    }

    public function add(cb: Callback<T>):CallbackLink {
        //var node = new ListCell(cb, this);
        //this.push(node);
        //return node;
        return this[this.push(new ListCell(cb, this)) - 1];
    }

    public function pre(cb: Callback<T>):CallbackLink {
        this.unshift(new ListCell(cb, this));
        return this[0];
    }

    //@:access(pmdb.async.Callback.Callback)
    public function copy():CallbackList<T> {
        var m:Array<ListCell<T>> = @:privateAccess this.map(cell -> new ListCell(cell.cb, this));
        for (idx in 0...length) @:privateAccess{
            m[idx].list = m;
        }
        return m;
    }

    public function invoke(data: T) {
        for (cell in this.copy()) {
            cell.invoke( data );
        }
    }

    public function clear():Void {
        for (cell in this.splice(0, this.length)) {
            cell.clear();
        }
    }

    public function invokeAndClear(data: T) {
        for (cell in this.splice(0, this.length)) {
            cell.invoke( data );
        }
    }
}
