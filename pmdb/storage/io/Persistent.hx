package pmdb.storage.io;

import pm.Object.Doc;
import pmdb.storage.IStorage.IStorageSync;
import pm.concurrent.rl.QueueWorker;
import pm.concurrent.rl.Task;
import pmdb.storage.Storage;
import pmdb.storage.Format;

import pm.*;
import pm.async.Promise;
import pm.async.Signal;
import pm.async.Callback;
import pm.concurrent.RunLoop;

import haxe.Unserializer;
import haxe.ds.Option;

#if (js && hxnodejs)
import js.node.Fs;
#end

using pm.Strings;
using pm.Arrays;
using pm.Functions;
using pm.Options;
using pm.async.Async;

class Persistent<T> {
    public final __id:Int = pm.HashKey.next();
    @:noCompletion
    public var __value(default, set):T = null;
    private var __encodedValue(default, null):String = '';

    public var currentState(get, never):T;
    private var __lastRaw:Maybe<String> = None;
    private var __name:String;
    private var format: Format<T, String> = cast Format.hx();
    private var storage: IStorageSync = null;
    private var __connected:Bool = false;
    private var __dirty:Bool = false;
    private var __uRet:Maybe<T> = None;

    public var options:{
        allowDirectModification: Bool,
        overrides: {
            ?open: PUpdate<T>,
            ?pull: PUpdate<T>,
            ?push: PUpdate<T>
        }
    };

    public function new(?initialValue: T) {
        this.__value = initialValue;
        this.__name = 'persistent-${__id}';
        this.options = {
            allowDirectModification: true,
            overrides: {}
        };

        #if (sys || hxnodejs)
        this.storage = new FileSystemStorage();
        #else
            #error
        #end
    }

    private inline function set___value(new_state: T):T {
        this.__value = new_state;
        this.__encodedValue = format.encode(__value);
        return this.__value;
    }

    /**
      initiates syncronicity between the instance and its destination file
     **/
    public function open() {
        if (nn(options.overrides.open))
            return options.overrides.open(this);
        
        if (storage.exists(__name)) {
            pull();
        }

        this.__connected = true;
    }

    public function clear() {
        storage.unlink(__name);
    }

    public function pull(firstPull=true) {
        switch tryPullData(firstPull) {
            case Success({encoded:encoded, decoded:decoded}):
                @:bypassAccessor this.__value = decoded;
                this.__encodedValue = encoded;

            case Failure(error):
                throw error;
        }
    }

    public inline function assign(newState: T):Bool {
        /**
          [TODO] try testing equality by simply comparing serialized data
         */
        var areDifferent = !Arch.areThingsEqual(currentState, newState);
        if (areDifferent) {
            __value = newState;
            __dirty = true;
        }
        return __dirty;
    }

    public dynamic function testEquality(a:T, b:T):Bool {
        return a == b;
    }

    public inline function isDirty():Bool {
        return __dirty;
    }

    public inline function apply(u: PUpdate<T>) {
        return u(this);
    }

    public inline function update(u: PUpdate<T>):Bool {
        var updatedState:T = call_update(this, u);
        return assign(updatedState);
    }

    static inline function call_update<T>(self:Persistent<T>, update:PUpdate<T>):T {
        assert(self.__uRet.isNone());
        self.apply(update);
        return switch (self.__uRet : Option<T>) {
            case Some(v):
                self.__uRet = None;
                v;
            case None:
                throw new pm.Error('Void pointer error');
        }
    }

    static inline function apply_update<T>(self:Persistent<T>, update:PUpdate<T>, framework:PModifier<T>):Bool {
        return switch framework(self, ()->update(self)) {
            case Success(result): result;
            case Failure(error):
                throw error;
        }
    }

    public function commit():Bool {
        var willPush = __dirty;
        if (willPush) {
            push();
            __dirty = false;
        }
        else if (__encodedValue != null) {
            var currentEncodedValue:String = format.encode(currentState);
            if (currentEncodedValue != __encodedValue) {
                push(currentEncodedValue);
                __dirty = false;
                willPush = true;
            }
        }
        return willPush;
    }

    function get_currentState() return __value;

    public function push(?overriddenEncoded: String) {
        var raw:String = nor(overriddenEncoded, format.encode(__value));
        if (raw.empty())
            throw '<Empty>';
        
        storage.writeFile(__name, raw);
        Console.log('<u><invert><#0F0>[INFO]:<//> ${haxe.Json.stringify(raw)}');
    }

    public function tryPullData(firstPull: Bool) {
        try {
            var raw:String = storage.readFile(__name);
            if (raw.empty())
                throw '<Empty>';
            __lastRaw = raw;
            var dec = format.decode(raw);
            return Success({encoded:raw, decoded:dec});
        }
        catch (errorMsg: String) {
            switch errorMsg {
                case '<Empty>':
                    try {
                        if (firstPull) {
                            __dirty = true;
                        }
                        return Success({encoded:format.encode(__value), decoded:__value});
                    }
                    catch (e: Dynamic) {
                        return Failure(e);
                    }

                default:
                    throw errorMsg;
            }
        }
        catch (e: Dynamic) {
            return Failure(e);
        }
    }

    public function configure(cfg:{?name:String, ?format:Format<T, String>}):Persistent<T> {
        if (nn(cfg.name)) {
            this.__name = cfg.name;
        }
        if (nn(cfg.format))
            setFormat(cfg.format);
        return this;
    }

	public function setFormat(fmt:Format<T, String>) {
		if (this.format != null) {
			var prev = this.format;
			try {
				this.format = fmt;
				reformat(prev, this.format);
			} catch (e:Dynamic) {
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
        catch (err:Dynamic) {
			throw new pm.Error.ValueError(err, 'reformat failed');
		}
	}

    public dynamic function copyState(?state: T):T {
        if (state == null) state = currentState;
        return Arch.clone(state, CloneMethod.ShallowRecurse);
    }
}

typedef PCallback<T> = Callback<Persistent<T>>;
typedef PStateCallback<T> = Callback<T>;
typedef PModLambda<T> = T -> T;
typedef PModifier<T> = (state:Persistent<T>, f:Void->Void) -> Outcome<Bool, Dynamic>;

@:forward
@:callable
@:access(pmdb.storage.io.Persistent)
abstract PUpdate<T> (PCallback<T>) from PCallback<T> to PCallback<T> {
	@:access(pmdb.storage.io.Persistent)
    @:from public static inline function mod<T>(modifier: PModLambda<T>):PUpdate<T> {
        return function(p: Persistent<T>) {
            var newState:T = modifier(p.currentState);
            p.__uRet = Some(newState);
        }
    }
    @:from public static inline function mod2<T>(modifier: (p:Persistent<T>, state:T)->T):PUpdate<T> {
        return function(p:Persistent<T>) {
            var newState = modifier(p, p.currentState);
            p.__uRet = Some(newState);
        };
    }

    @:from
    public static function modCb<T>(modifier: T -> Void):PUpdate<T> {
        return function(p:Persistent<T>, state: T):T {
            var tmp:T = p.copyState(state);
            modifier(tmp);
            return tmp;
        }
    }

    @:from public static inline function const<T>(state: T):PUpdate<T> {
        return mod(_ -> state);
    }

    public static function appender<T:{}>(tail: T):PUpdate<T> {
        return function(state: T):T {
            var o:Doc = Doc.unsafe(state);
            o.pull(tail);
            return ((o : Dynamic) : T);
        }
    }
}

