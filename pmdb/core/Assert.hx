package pmdb.core;

import pmdb.core.ds.Lazy;

import pmdb.core.Error;

import haxe.PosInfos;

class Assert {
    /**
      throws an error if [condition] is not met
     **/
    public static inline function assert<E>(condition:Lazy<Bool>, ?msg:Lazy<E>, ?pos:PosInfos):Void {
        #if (debug || keep_assertions)
        if (!condition.get())
            _toss(msg, pos);
        #end
    }

    /**
      throws an error if [fn] doesn't cause an error to be thrown
     **/
    public static inline function assertThrows<E>(fn:Void->Void, ?msg:Lazy<E>, ?pos:PosInfos):Void {
        #if (debug || keep_assertions)
        try {
            fn();
            _toss(msg, pos);
        }
        catch (e: Dynamic) {
            //
        }
        #end
    }

    /**
      utility method for throwing an exception
     **/
    private static function _toss<E>(?s:Lazy<E>, ?pos:PosInfos) {
        var uS:E = s != null ? s.get() : null;
        if (s == null || (uS is String)) {
            throw new AssertionFailureError(s.map(e -> cast(e, String)), pos);
        }
        else {
            throw s.get();
        }
    }
}

class AssertionFailureError extends Error {}
