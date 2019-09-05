package pmdb.storage.io;

import pm.concurrent.rl.QueueWorker;
import haxe.Unserializer;
import pm.concurrent.rl.Task;
import pmdb.storage.Storage;
import pmdb.storage.Format;

import pm.*;
import pm.async.Promise;
import pm.async.Signal;
import pm.async.Callback;
import pm.concurrent.RunLoop;

import haxe.ds.Option;

#if !(js && hxnodejs)
import js.node.Fs;
#end

using pm.Strings;
using pm.Arrays;
using pm.Functions;
using pm.Options;
using pm.async.Async;

class Persistent<T> {
    private final __id:Int = pm.HashKey.next();

    private var __value:T = null;
    private var __lastRaw:Maybe<String> = None;
    private var __name: String;
    private var format: Format<T, String> = cast Format.hx();
    private var storage: IStorage = null;
    private var __connected:Bool = false;
    private var __touched:Bool = false;
    private var __pushing:Bool = false;

    private var __synced:Signal<T> = new Signal();

    public function new(?initialState: T) {
        __value = initialState;
        __name = 'persist-${__id}';

        __synced.once(t -> {
            onOpened( t );
        });

        // ... yep
        if (Persistent._butler == null) {
            Persistent._butler = new PersistenceWorker();
            RunLoop.current.work(_butler);
        }

        _all.push(this);
    }

    public function configure(cfg: {?name:String, ?format:Format<T, String>}) {
        inline function h<T2>(ref:Null<T2>, fn:Callback<T2>) {
            if (ref != null) {
                fn.invoke(ref);
            }
        }

        h(cfg.name, n -> setPath(n));
        h(cfg.format, fmt -> setFormat(fmt));

        return this;
    }

    public function setFormat(fmt: Format<T, String>) {
        if (this.format != null) {
            var prev = this.format;
            try {
               this.format = fmt;
               reformat(prev, this.format);
            }
            catch (e: Dynamic) {
                this.format = prev;
                throw e;
            }
        }
        else {
            this.format = fmt;
        }
    }

    function reformat(oldFormat:Format<T, String>, newFormat:Format<T, String>) {
        try {
            __lastRaw = __lastRaw.map(oldFormat.decode).map(newFormat.encode);
        }
        catch (err: Dynamic) {
            throw new pm.Error.ValueError(err, 'reformat failed');
        }
    }

    public inline function setPath(path: pm.Path):Void {
        this.__name = '$path';
    }

    public function release() {
        _all.remove(this);

    }

    public dynamic function onOpened(state: T) {
        return ;
    }

    public inline function peek():T return __value;
    public inline function write(state: T) {
        this.__value = state;
        mark();
    }
    public inline function update(f: T -> T, push=false) {
        write(f(peek()));
        if (push)
            commit();
    }

    public function mark() {
        Sys.print('CALL ::mark');
        if (!__touched) {
            Sys.println(' ==>> TOUCH event');
            __touched = true;
            _dirty.push(this);
        }
    }

    @:keep function toString() {
        return 'Persistent(#$__id)';
    }

    public function commit() {
        Sys.println('CALL commit');
        /**
          just feel I should let future-me know when I've written code that'll overload the write-queue
         **/
        // if (_dirty.has(this)) {
        //     if (!__touched) {
        //         throw new pm.Error.WTFError('$this was still in the commit-queue, but not marked as "dirty"');
        //     }
        //     else {
        //         throw new pm.Error('$this was added to the commit-queue after SCHEDULE_PUSHES');
        //     }
        // }

        // 
        // var fork = pm.Arch.clone(__value, ShallowRecurse);
        if (!__pushing && storage != null) {
            //
            function push(d: String) {
                __pushing = true;
                __lastRaw = d;
                storage.writeFile(__name, d)
                    .then(x -> {
                        __pushing = false;
                        pm.Assert.assert(x);
                        trace('push successful');
                    })
                    .catchException(e -> {
                        __pushing = false;
                        throw e;
                    });
            }
            //
            deferCall(
                push,
                null,
                [format.encode(__value)]
            );

            return ;
        }

        trace('commit() called redundantly');
    }

    public function connect(storage: IStorage) {
        if (this.storage == null) {
            this.storage = storage;
            
            defer(onConnected);
        }
    }
    
    private function onConnected() {
        trace('onConnected fired');
        __connected = true;
        function Suicide(e: Dynamic) {
            throw e;
        }
        
        function pull() {
            trace('pull fired');
            storage.readFile(__name).then(
                function(inflated: String) {
                    trace('remote received');
                    __lastRaw = inflated;
                    // try {
                        var dec = format.decode(inflated);
                        this.__value = dec;
                        if (dec != null) {
                            defer(__synced.broadcast.bind(dec));
                        }
                    // }
                },
                Suicide
            );
        }

        function exist(b: Bool)
            if (b)
                pull();
            else
                trace('first persistent persisted to "$__name"');

        storage.exists(__name).then(exist, Suicide);
    }

    private inline function deferCall(f:haxe.Constraints.Function, ?o:Dynamic, args:Array<Dynamic>) {
        return defer(() -> {
            Reflect.callMethod(o, f, args);
        });
    }
    private inline function defer(f: Task):CallbackLink {
        return RunLoop.current.work( f );
    }

    private static var _butler:Null<PersistenceWorker> = null;
    @:allow(pmdb.storage.io.Persistent.PersistenceWorker)
    private static var _dirty:Array<Persistent<Dynamic>> = new Array();
    private static var _all:Array<Persistent<Dynamic>> = new Array();

    static function _tick() @:privateAccess {
        if (_all.empty()) {
            suspend();
        }
        if (_butler != null) {
            if (_butler._quit.get()) {
                _butler = null;
            }
        }
    }

    public static inline function suspend():Void @:privateAccess {
        if (_butler != null)
            _butler._quit.set(true);
    }
}

class PersistenceWorker extends RepeatableFunctionTask {
    private final _quit:Ref<Bool>;
    public function new() {
        _quit = pm.Ref.to(false);
        function _():TaskRepeat {
            _tick(_quit);

            return
                if (_quit.get())
                    TaskRepeat.Done;
                else
                    TaskRepeat.Continue;
        }
        super(_);
    }

    function _tick(stop:pm.Ref<Bool>) @:privateAccess {
        var tmp = Persistent._dirty;
        Persistent._dirty = [];
        
        for (p in tmp) {
            if (p.__touched) {
                p.commit();
                p.__touched = false;
            }
        }
        Persistent._tick();
    }
}

enum PersistentStatus {
    Disconnected;
    Auth;// still validating; not connected to anything yet
    Receiving;// requested clone; haven't received it yet
    Synced;// self and `remote` are synchronized with each other; no changes have yet been made to either
    Staged;// changes have been made to the local state, but not yet committed
    Committing;// commit has begun, but not finished
    Ahead;// >0 commits have yet to be pushed onto remote
    Merging;// 2-way MERGE has been triggered, and is in-progress
    Pushing;// writing compacted data-state
    
    // FastForward;
}