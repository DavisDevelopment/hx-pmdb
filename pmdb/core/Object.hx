package pmdb.core;

import haxe.DynamicAccess;

import Reflect as O;

@:runtimeValue
@:forward
abstract Object<T> (DynamicAccess<T>) from Dynamic<T> to Dynamic<T> from DynamicAccess<T> to DynamicAccess<T> {
    /* Constructor Function */
    public inline function new() {
        this = {};
    }

/* === Operator Methods === */

    @:arrayAccess
    public inline function get(key: String):Null<T> return this.get(key);

    @:arrayAccess
    public inline function set(key:String, value:T):Null<T> return this.set(key, value);

    public inline function copy():Object<T> {
        return this.copy();
    }

    public inline function clone(?onto: Object<T>):Object<T> {
        return Arch.deepCopy(this, onto);
    }

    public function pull(src: Object<T>) {
        for (key in src.keys()) {
            this[key] = src[key];
        }
    }

    @:op(A + B)
    public static function sum<T>(left:Object<T>, right:Object<T>):Object<T> {
        var res:Object<T> = left.copy();
        for (key in right.keys()) {
            res[key] = right[key];
        }
        return res;
    }

/* === Casting Methods === */

    @:from
    public static inline function of<T>(o: Dynamic<T>):Object<T> {
        return o;
    }
}
