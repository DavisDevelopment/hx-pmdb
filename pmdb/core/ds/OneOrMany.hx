package pmdb.core.ds;

import haxe.ds.ReadOnlyArray;

import haxe.macro.Expr;

@:forward(length, iterator, keyValueIterator)
abstract OneOrMany<T> (ReadOnlyArray<T>) from ReadOnlyArray<T> to ReadOnlyArray<T> {
    public inline function isOne():Bool {
        return this.length == 1;
    }

    public inline function isMany():Bool {
        return !isOne();
    }

    @:to
    public inline function asOne():T {
        return this[0];
    }

    @:to
    public inline function asMany():ReadOnlyArray<T> {
        return this;
    }

    @:to
    inline function asArray():Array<T> {
        return cast this;
    }

    public inline function map<O>(fn: T -> O):OneOrMany<O> {
        return many(this.map( fn ));
    }

    @:op( a.b )
    public static macro function resolveGet<T>(self:ExprOf<OneOrMany<T>>, field:String) {
        return macro $self.map(x -> x.$field);
    }

    @:from
    public static inline function many<T>(values: Array<T>):OneOrMany<T> {
        return (values: ReadOnlyArray<T>);
    }

    @:from
    public static inline function one<T>(value: T):OneOrMany<T> {
        return [value];
    }
}
