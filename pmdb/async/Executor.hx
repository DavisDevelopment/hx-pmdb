package pmdb.async;

import pm.async.impl.Defer;
import pm.async.*;
import pm.async.Deferred;
import pm.*;

import haxe.extern.EitherType as Or;
import haxe.Constraints.Function;

using pm.Functions;

class Executor {
    public var cats: Map<String, IQueue<Task>>;
    //public var queue: IQueue<Task>;
    private var isClosed(default, null): Bool;

    public function new() {
        //queue = new LinkedQueue();
        cats = new Map();
        isClosed = false;
    }

    private function category(n: String):IQueue<Task> {
        if (!cats.exists( n )) {
            cats[n] = new LinkedQueue<Task>();
        }
        return cats[n];
    }

    public function add(n:String, t:Task):Promise<Float> {
        var runit:Bool = false;
        if (category(n).isEmpty()) {
            runit = true;
        }
        category( n ).enqueue( t );

        if ( runit ) {
            nextTick(() -> _next_( n ));
        }
        
        return Promise.deferred(t.de).map(function(_) {
            return (t.end - t.begin);
        });
    }

    public function exec<T>(n:String, param:Or<{?o:Dynamic, f:Function, args:Array<Dynamic>}, Void->Promise<T>>, ?param2:Promise<T>->Void):Promise<Float> {
        if (Reflect.isObject( param )) {
            var opts:{?o:Dynamic, f:Function, args:Array<Dynamic>} = cast param;
            return exec(n, function():Promise<T> {
                return cast Reflect.callMethod(opts.o, opts.f, opts.args);
            });
        }
        else {
            var f:Void->Promise<T> = cast param;
            var fn;
            if (param2 == null) {
                fn = (() -> f().noisify());
            }
            else {
                fn = function() {
                    var p = f();
                    param2( p );
                    return p.noisify();
                };
            }
            return add(n, new Task( fn ));
        }
    }

    public function stop() {
        isClosed = true;
    }

    /**
      execute the next Task in the queue
     **/
    function _next_(n: String) {
        var queue = category( n );
        if (!queue.isEmpty()) {
            var task = queue.dequeue();
            task.await(function() {
                if (!queue.isEmpty() && !isClosed) {
                    nextTick(() -> _next_( n ));
                }
            });
            task.start();
        }
    }

    static function nextTick(fn: Void -> Void):Promise<Float> {
        return Promise.asyncFulfill(function(ret) {
            Defer.defer(function() {
                var begin = timestamp();
                fn();
                var took = (timestamp() - begin);
                ret(took);
            });
        });
        // return new Promise(function(yes, no) {
        //     Callback.defer(function() {
        //         var begin = timestamp();
        //         fn();
        //         var took = (timestamp() - begin);
        //         yes( took );
        //     });
        // });
    }
}

class Task {
    public var f(default, null): Void -> Promise<Noise>;
    public var de(default, null): AsyncDeferred<Noise, Dynamic>;
    private var p(default, null): Null<Promise<Noise>>;
    public var begin(default, null): Null<Float>;
    public var end(default, null): Null<Float>;

    public function new(fn) {
        f = fn;
        p = null;
        de = Deferred.create();

        begin = null;
        end = null;
    }

    public function start() {
        p = f();
        begin = timestamp();
        p.then(
            function(v) {
                end = timestamp();
                de.done( v );
            },
            function(e) {
                end = timestamp();
                de.fail( e );
            }
        );
    }

    public function await(fn: Void->Void) {
        Promise.deferred(de).always(fn);
        // Promise.make( de ).then(
        //     function(_) {
        //         fn();
        //     },
        //     function(_) {
        //         fn();
        //     }
        // );
    }

    public inline function isEnded():Bool {
        return (end != null);
    }
}
