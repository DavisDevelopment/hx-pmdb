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
        this.position = position;
        this._msg = (msg != null ? msg : Lazy.ofFunc(prettyPrintStackTrace.bind()));
        _cstack = None;
        _estack = None;
    }

/* === Instance Methods === */

    public function prettyPrintStackTrace():String {
        if (exceptionStack == null)
            return 'Error';
        return CallStack.toString( exceptionStack );
    }

    @:noCompletion
    public function captureStacks() {
        _cstack = Some(CallStack.callStack());
        _estack = Some(CallStack.exceptionStack());
    }

/* === Calculated Instance Fields === */

    public var message(get, never): String;
    inline function get_message():String return _msg.get();

    public var callStack(get, never): Null<Array<StackItem>>;
    inline function get_callStack():Null<Array<StackItem>> return _cstack.getValue();

    public var exceptionStack(get, never): Null<Array<StackItem>>;
    inline function get_exceptionStack():Null<Array<StackItem>> return _estack.getValue();

/* === Instance Fields === */

    public var position(default, null): PosInfos;

    private var _msg(default, null): Lazy<String>;

    /* the call-stack leading up to [this] Error */
    private var _cstack(default, null): Option<Array<StackItem>>;

    /* the actual exception-stack as given by Haxe */
    private var _estack(default, null): Option<Array<StackItem>>;
}
