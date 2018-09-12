package pmdb.core;

import tannus.math.TMath as Math;

using tannus.ds.SortingTools;
using tannus.FunctionTools;

@:forward(compare)
abstract Comparator<T> (IComparator<T>) from IComparator<T> to IComparator<T> {
/* === Instance Methods === */

    public inline function toArrayComparator():Comparator<Array<T>> {
        return arrayComparator(this);
    }

    public inline function map<O>(f: T->O):Comparator<O> {
        return cast new MappedComparator(cast this, f);
    }

/* === Static Instances === */

/* === Factories === */

    @:noUsing @:native('_bool')
    public static inline function boolean():Comparator<Bool> return BooleanComparator.make();
    @:noUsing @:native('_int')
    public static inline function int():Comparator<Int> return NumComparator.make();
    @:noUsing @:native('_float')
    public static inline function float():Comparator<Float> return NumComparator.make();
    @:noUsing @:native('_string')
    public static inline function string():Comparator<String> return StringComparator.make();
    public static inline function date():Comparator<Date> return new DateComparator();
    public static inline function any<T>():Comparator<T> return cast AnyComparator.make();
    
    @:from
    @:noUsing
    public static function create<T>(compare:T->T->Int):Comparator<T> {
        return new FComparator( compare );
    }

    @:noUsing
    public static function arrayComparator<T>(itemComparator: Comparator<T>):Comparator<Array<T>> {
        return new ArrayComparator( itemComparator );
    }

    @:noUsing
    public static function makeNullable<T>(c: Comparator<T>):Comparator<Null<T>> {
        return new NullableComparator( c );
    }
}

interface IComparator<T> {
    function compare(a:T, b:T):Int;
}

private class ReflectComparator<T> implements IComparator<T> {
    /* Constructor Function */
    public function new() {}
    public function compare(x:T, y:T):Int return Reflect.compare(x, y);
}

class NumComparator<T:Float> extends ReflectComparator<T> {
    static var i:NumComparator<Float> = new NumComparator();
    public static inline function make<T:Float>():NumComparator<T> {
        return cast i;
    }
}

class StringComparator extends ReflectComparator<String> {
    static var i:StringComparator = new StringComparator();
    public static inline function make():StringComparator return i;
}

class BooleanComparator implements IComparator<Bool> {
    public function new() {}
    public function compare(x:Bool, y:Bool):Int {
        #if js
        return Reflect.compare(x, y);
        #else
        return Reflect.compare(x?1:0, y?1:0);
        #end
    }

    static var i:BooleanComparator = new BooleanComparator();
    public static inline function make():BooleanComparator return i;
}

class DateComparator implements IComparator<Date> {
    public function new() {}
    public function compare(x:Date, y:Date):Int {
        return Reflect.compare(x.getTime(), y.getTime());
    }
}

private class NullableComparator<T> implements IComparator<Null<T>> {
    /* Constructor Function */
    public function new(c) {
        this.c = c;
    }

    public function compare(a:Null<T>, b:Null<T>):Int {
        if (a == b) return 0;
        return switch [a, b] {
            case [null, _]: -1;
            case [_, null]: 1;
            case _: c.compare(a, b);
        }
    }

    var c(default, null): Comparator<T>;
}

private class ArrayComparator<T> implements IComparator<Array<T>> {
    var c(default, null): Comparator<T>;
    /* Constructor Function */
    public function new(c) {
        this.c = c;
    }

    public function compare(a:Array<T>, b:Array<T>):Int {
        var comp;
        for (i in 0...Math.min(a.length, b.length)) {
            comp = c.compare(a[i], b[i]);
            switch comp {
                case 0:
                case _:
                    return comp;
            }
        }
        return Reflect.compare(a.length, b.length);
    }
}

private class AnyComparator<T> implements IComparator<T> {
    /* Constructor Function */
    function new() {}
    public function compare(x:T, y:T):Int {
        return SortingTools.compareAny(x, y);
    }

    static var i:AnyComparator<Any> = new AnyComparator();
    public static inline function make():AnyComparator<Any> return i;
}

private class MappedComparator<TFrom, TTo> implements IComparator<TFrom> {
    /* Constructor Function */
    public function new(c, f) {
        this.c = c;
        value = f;
    }

    public function compare(x:TFrom, y:TFrom):Int {
        return c.compare(value(x), value(y));
    }

    var c(default, null): Comparator<TTo>;
    var value(default, null): TFrom -> TTo;
}

private class FComparator<T> implements IComparator<T> {
    var f(default, null): T->T->Int;
    /* Constructor Function */
    public function new(f) {
        this.f = f;
    }
    public function compare(a:T, b:T):Int return f(a, b);
}
