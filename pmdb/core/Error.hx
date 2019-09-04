package pmdb.core;

import pm.Lazy;
import pm.Error as PmError;

import haxe.ds.Option;

import haxe.CallStack;
import haxe.CallStack.StackItem;
import haxe.PosInfos;

using pm.Options;

class Error extends PmError {
    /* Constructor Function */
    public function new(?msg:Lazy<String>, ?position:PosInfos) {
        super((msg != null ? msg.get() : Lazy.ofFn(() -> defaultMessage())), position);
        captureStacks();
    }

/* === Instance Methods === */

    function defaultMessage():String {
        return prettyPrintStackTrace();
    }

    public function prettyPrintStackTrace():String {
        if (exceptionStack == null)
            return 'Error';
        return CallStack.toString( exceptionStack );
    }

    @:noCompletion
    public inline function captureStacks() {
        _cstack = Some(CallStack.callStack());
        _estack = Some(CallStack.exceptionStack());
    }

/* === Calculated Instance Fields === */

    public var callStack(get, never): Null<Array<StackItem>>;
    inline function get_callStack():Null<Array<StackItem>> return _cstack.getValue();

    public var exceptionStack(get, never): Null<Array<StackItem>>;
    inline function get_exceptionStack():Null<Array<StackItem>> return _estack.getValue();

/* === Instance Fields === */

    //public var position(default, null): PosInfo,ci;
    //public var name(default, null): String;

    private var _msg(default, null): Lazy<String>;

    /* the call-stack leading up to [this] Error */
    private var _cstack(default, null): Option<Array<StackItem>>;

    /* the actual exception-stack as given by Haxe */
    private var _estack(default, null): Option<Array<StackItem>>;
}

class ValueError<T> extends Error {
    /* Constructor Function */
    public function new(value:Lazy<T>, ?msg:Lazy<String>, ?position:PosInfos) {
        super(msg, position);

        this._value = value;
    }

    public var value(get, never): T;
    inline function get_value():T return _value.get();

    private var _value(default, null): Lazy<T>;
}

class NotImplementedError extends Error {}
class WTFError extends Error {}
