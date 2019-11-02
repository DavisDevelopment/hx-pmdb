package pmdb.async;

import pm.*;
import pm.async.*;
import pm.async.Callback;
import pm.async.Deferred;

import haxe.ds.Option;

using pm.Options;
using pm.Outcome;
using pm.Functions;

class Trigger<Result, Err> {
    public var resolve:Result -> Void;
    public var reject:Err -> Void;
    
    private var _listeners: CallbackList<Outcome<Result, Err>>;
    private var _status: Option<Outcome<Result, Err>>;

#if js
    @:noCompletion
    public var promise:js.lib.Promise;
#else
    //
#end    
    public function handle(f: Outcome<Result, Err> -> Void) {
        #if js

    }

    public function new() {
        _status = None;
        _listeners = new CallbackList();
        
        function complete(o: Outcome<Result, Err>) {
            if (status.isNone() && listeners != null) {
                status = Some(o);
                defer(() -> {
                    listeners.invokeAndClear(o);
                    listeners = null;
                });
            }
        }


        function then(onFulfilled) {
            #if js
            promise.then(x -> onFulfilled);
            #else
            throw 'TODO';
            #end
        }
        #if js var isCaught:Bool = false; #end
        function catchError(onRejected: Err -> Bool) {
            #if js
            promise.catchError(function(error: Dynamic) {
                isCaught = onRejected(error);
            });
            #else
            //
            #end
        }

        var listen = {then: then, catchError:catchError};

        //
        #if js
        this.promise = new js.lib.Promise(function(_resolve, _reject) {
            this.resolve = _resolve;
            this.reject = _reject;
        });
        promise.then;
        #end
    }

    public inline function then(successCallback: Callback<Result>):Void {
        #if js
        this.promise.then(r -> successCallback.invoke(r));
        #else
        throw 'poop';
        #end
    }
}