package pmdb.core;

import tannus.ds.Lazy;

import pmdb.core.Error;

import haxe.PosInfos;

class Assert {
    public static inline function assert(condition:Lazy<Bool>, ?msg:Lazy<String>, ?pos:PosInfos):Void {
        if (!condition.get())
            _toss(msg, pos);
    }

    public static inline function assertThrows(fn:Void->Void, ?msg:Lazy<String>, ?pos:PosInfos):Void {
        try {
            fn();
            _toss(msg, pos);
        }
        catch (e: Dynamic) {
            //
        }
    }

    private static inline function _toss(?s:Lazy<String>, ?pos:PosInfos) {
        throw new AssertionFailureError(s, pos);
    }
}

class AssertionFailureError extends Error {

}
