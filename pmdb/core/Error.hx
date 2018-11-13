package pmdb.core;

import tannus.ds.Lazy;
import haxe.ds.Option;

import haxe.CallStack;
import haxe.CallStack.StackItem;
import haxe.PosInfos;

using tannus.async.OptionTools;

class Error {
    /* Constructor Function */
    public function new(?msg:Lazy<String>, ?position:PosInfos) {
        name = 'Error';
        this.position = position;
        this._msg = (msg != null ? msg : Lazy.ofFunc(() -> defaultMessage()));
        //_cstack = None;
        //_estack = None;
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

    public function toString():String {
        return '$name: $message';
    }

    @:noCompletion
    public inline function captureStacks() {
        _cstack = Some(CallStack.callStack());
        _estack = Some(CallStack.exceptionStack());
    }

    static function __init__() {
        //#if js
        //js.Object.defineProperty(untyped Error.prototype, 'message', {
            //get: untyped Error.prototype.get_message
        //});
        //#end
    }

/* === Calculated Instance Fields === */

    public var message(get, never): String;
    @:keep function get_message():String return _msg.get();

    public var callStack(get, never): Null<Array<StackItem>>;
    inline function get_callStack():Null<Array<StackItem>> return _cstack.getValue();

    public var exceptionStack(get, never): Null<Array<StackItem>>;
    inline function get_exceptionStack():Null<Array<StackItem>> return _estack.getValue();

/* === Instance Fields === */

    public var position(default, null): PosInfos;
    public var name(default, null): String;

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
