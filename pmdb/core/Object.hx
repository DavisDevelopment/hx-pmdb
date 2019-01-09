package pmdb.core;

import haxe.DynamicAccess;

import pmdb.core.Arch;

import Reflect as O;

using Lambda;
using tannus.ds.ArrayTools;

//@:runtimeValue
@:forward
abstract Object<T> (DynamicAccess<T>) from Dynamic<T> to Dynamic<T> from DynamicAccess<T> to DynamicAccess<T> {
    /* Constructor Function */
    public inline function new() {
        this = {};
    }

/* === Operator Methods === */

    @:arrayAccess
    public inline function get(key: String):Null<T> {
        return this.get( key );
    }

    /**
      get the value of a nested field
     **/
    public inline function dotGet<O>(key: String):Null<O> {
        return Arch.getDotValue(this, key);
    }

    @:arrayAccess
    public inline function set(key:String, value:T):Null<T> {
        return this.set(key, value);
    }

    /**
      set the value of some nested field
     **/
    public inline function dotSet<O>(key:String, val:O):Void {
        Arch.setDotValue(this, key, val);
    }

    /**
      check for the existence of some nested property
     **/
    public inline function dotExists(key: String):Bool {
        return Arch.hasDotValue(this, key);
    }

    /**
      delete a nested field
     **/
    public inline function dotRemove(key: String):Bool {
        return Arch.delDotValue(this, key);
    }

    /**
      create and return a shallow copy of [this]
     **/
    public inline function copy():Object<T> {
        return Arch.clone_object(this, Shallow);
    }

    /**
      clone [this] Object
     **/
    public function clone(?method: CloneMethod):Object<T> {
        if (method == null)
            method = ShallowRecurse;
        return Arch.clone_object(this, method);
    }

    public function pull(src: Object<T>) {
        for (key in src.keys()) {
            this[key] = src[key];
        }
    }

    public function push(dest: Object<T>) {
        for (key in this.keys()) {
            dest[key] = this[key];
        }
    }

    public function pick(fields: Array<String>):Object<T> {
        final picked:Object<T> = Arch.emptyCopy( this );
        Arch.clone_object_onto(this, picked, fields);
        return picked;
    }

    public function without(fields: Array<String>):Object<T> {
        final sub:Object<T> = Arch.emptyCopy( this );
        final subFields = this.keys().filter(x -> fields.has( x ));
        Arch.clone_object_onto(this, sub, subFields);
        return sub;
    }

    @:op(A + B)
    public static function sum<T>(left:Object<T>, right:Object<T>):Object<T> {
        var res:Object<T> = left.copy();
        for (key in right.keys()) {
            res[key] = right[key];
        }
        return res;
    }

    @:resolve
    public static inline function getattr<T>(o:Object<T>, name:String):T {
        return o[name];
    }

    @:resolve
    public static inline function setattr<T>(o:Object<T>, name:String, value:T):T {
        return o[name] = value;
    }

/* === Casting Methods === */

    @:from
    public static inline function of<T>(o: Dynamic<T>):Object<T> {
        return o;
    }

    @:from
    public static inline function ofStruct<O:{}>(o: O):Object<Dynamic> {
        return of(cast o);
    }
}
