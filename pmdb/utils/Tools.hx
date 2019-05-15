package pmdb.utils;

import pmdb.core.Object;

class Tools {}

class Fn1x0 {
    public static inline function tap<T>(value:T, middle:T -> Void):T {
        middle( value );
        return value;
    }
}

/*
class Fn1x1 {
    //
    public static inline function apply<A, B>(value:A, fn:A -> B):B {
        return fn( value );
    }

    //o
    public static inline function apply2<A, B, C>(value:A, fnA:A -> B, fnB:B -> C):C {
        return fnB(fnA( value ));
    }
}
*/

class Dynamics {
    public static function asObject(o:Dynamic, safety = false):Object<Dynamic> {
        if (safety && !Reflect.isObject( o ))
            throw new ValueError(o, '$o cannot be cast to an Object');
        return cast Object.of( o );
    }
}
