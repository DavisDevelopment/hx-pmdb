package pmdb.async;

import pm.async.impl.PromiseObject;
import pm.async.impl.Defer;
import pm.async.*;
import pm.async.Deferred;
import pm.*;

import haxe.extern.EitherType as Or;
import haxe.Constraints.Function;

using pm.Functions;

/**
  the `Executor` type maintains a set of named execution queues, which are all processed concurrently
  within a given execution queue, tasks are executed in one-at-a-time in the order in which they were inserted
 **/
class Executor {
    public var cats: Map<String, IQueue<Task>>;
    //public var queue: IQueue<Task>;
    private var isClosed(default, null): Bool;

    public function new() {
        //queue = new LinkedQueue();
        cats = new Map();
        isClosed = false;
        Console.warn('<#F00>Executor.new</>');
    }

    /**
      [TODO] implement some system for deallocating the LinkedQueue instances which are no longer in use
     **/
    private function category(n: String):IQueue<Task> {
        if (!cats.exists( n )) {
            cats[n] = new LinkedQueue<Task>();
        }
        return cats[n];
    }

    /**
      append a given Task onto the Queue for the execution queue named by `category`
     **/
    public function add(category:String, task:Task):Promise<Float> {
        var runit:Bool = false;
        var queue = this.category(category);
        if (queue.isEmpty()) {
            runit = true;
        }

        queue.enqueue( task );
        trace('Task added to "$category" queue');

        if ( runit ) {
            nextTick(function() {
                _next_( category );
            });
        }
        
        return task.promise.map(function(_) {
            return task.end - task.begin;
        });
    }

    /**
      [TODO] deal with this fucking mess
     **/
    public function _exec<T>(n:String, param:Or<{?o:Dynamic, f:Function, args:Array<Dynamic>}, Void->Promise<T>>, ?param2:Promise<T>->Void):Promise<Float> {
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
    
    public function exec<T>(category:String, executor:Void->Promise<T>, ?hook:Callback<Promise<T>>):Promise<Float> {
        var taskExecutor;
        if (hook == null) {
            taskExecutor = function() {
                return executor().noisify();
            };
        }
        else {
            taskExecutor = function() {
                var promise = executor();
                hook(promise);
                return promise.noisify();
            };
        }
        return add(category, new Task(taskExecutor));
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
                    nextTick(function() {
                        _next_(n);
                    });
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
    }
}

class Task {
    @:native('executor')
    public var f(default, null): Void -> Promise<Noise>;
    // public var de(default, null): AsyncDeferred<Noise, Dynamic>;
    public var executionPromise:Null<Promise<Noise>>;
    public var promise(default, null): Promise<Noise>;
    public final trigger: PromiseTriggerObject<Noise>;
    public var begin(default, null): Null<Float>;
    public var end(default, null): Null<Float>;

    public function new(fn) {
        f = fn;
        promise = null;
        // de = Deferred.create();
        trigger = Promise.trigger();
        promise = Promise.createFromTrigger(trigger);
        executionPromise = null;
        begin = null;
        end = null;
    }

    public function start() {
        if (executionPromise == null && begin == null && end == null) {
            executionPromise = f();
            begin = timestamp();
            executionPromise.handle(o -> switch o {
                case Success(result):
                    end = timestamp();
                    trigger.resolve(result);

                case Failure(error):
                    end = timestamp();
                    trigger.reject(error);
            });
        }
        else {
            throw new Error('Cannot start a Task which has already been started');
        }
    }

    public function await(fn: Void -> Void) {
        promise.always( fn );
    }

    public inline function isEnded():Bool {
        return (end != null);
    }
}
