package pmdb.async;

import pmdb.async.Callback;
import pmdb.core.ds.*;

class Signal<T> {
    public function new() {
        //initialize variables
        ll = new CallbackList<T>();
    }

    public inline function dispose() {
        clear();
        ll = null;
    }

    public inline function on(fn: Callback<T>):CallbackLink {
        return listen( fn );
    }

    public inline function once(fn: Callback<T>):CallbackLink {
        return listen(fn, null, true);
    }

    public inline function before(fn:Callback<T>, ?once:Bool):CallbackLink {
        return listen(fn, once);
    }

    public function listen(fn:Callback<T>, prepend=false, once=false):CallbackLink {
        var lnk:CallbackLink = null;
        var callback:Callback<T> = if (once) 
            (function(x) {
                fn.invoke( x );
                lnk.cancel();
            })
        else fn;

        if ( !prepend ) {
            lnk = ll.add( callback );
        }
        else {
            lnk = ll.pre( callback );
        }

        return lnk;
    }

    /**
      @param awaitAcknowledge {Bool} whether broadcast should be sequential or simultaneous
     **/
    public function broadcast(data:T, awaitAcknowledge=true) {
        ll.invoke( data );
        return this;
    }

    public function clear() {
        ll.clear();
    }

    public inline function listenerCount() {
        return ll.length;
    }

    private var ll(default, null): CallbackList<T>;
}
