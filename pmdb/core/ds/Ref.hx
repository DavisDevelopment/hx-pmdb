package pmdb.core.ds;

import haxe.ds.Vector;

abstract Ref<T> (Vector<T>) {
    public inline function new() {
        this = new Vector( 1 );
    }

    @:to
    public inline function get():T {
        return this[0];
    }

    public inline function set(v: T):T {
        return this[0] = v;
    }

    public inline function assign(v: T) {
        this[0] = v;
    }

    public var value(get, set): T;
    private inline function get_value():T return this[0];
    private inline function set_value(v):T return (this[0] = v);

    @:to
    public inline function toString():String {
        return '@[${Std.string(value)}]';
    }

    @:noUsing @:from
    public static inline function to<T>(v: T):Ref<T> {
        var ret = new Ref();
        ret.assign( v );
        return ret;
    }
}
