package pmdb.core;

import tannus.ds.Comparable;
import tannus.math.TMath as Math;

using tannus.ds.SortingTools;
using tannus.FunctionTools;

@:forward
abstract Equator<T> (IEquator<T>) from IEquator<T> {
/* === Instance Methods === */

    public inline function map<Out>(f: Out -> T):Equator<Out> {
        return new MappedEquator<T, Out>(this, f);
    }

/* === Factory Methods === */

    public static inline function any():Equator<Any> {
        return BaseEquator.make();
    }

    @:from @:noUsing
    public static function create<T>(feq: T->T->Bool):Equator<T> {
        return new FEquator( feq );
    }

    @:noUsing
    public static function numeric<T:Float>(?epsilon: Float):Equator<T> {
        return new NumericalEquator( epsilon );
    }

    @:to @:noUsing
    public static function array<T>(item: Equator<T>):Equator<Array<T>> {
        return new ArrayEquator( item );
    }

    @:noUsing
    public static function enumValue<E:EnumValue>(e: Enum<E>):Equator<E> {
        return new EnumValueEquator( e );
    }
}

class BaseEquator<T> implements IEquator<T> {
    /* Constructor Function */
    public function new() { }
    public function equals(a:T, b:T):Bool {
        return (a == b);
    }

    private static var inst:BaseEquator<Dynamic> = new BaseEquator();
    public static inline function make<T>():BaseEquator<T> {
        return cast inst;
    }
}

class ArrayEquator<T> extends BaseEquator<Array<T>> {
    /* Constructor Function */
    public function new(item) {
        super();

        this.item = item;
    }

    override function equals(a:Array<T>, b:Array<T>):Bool {
        if (super.equals(a, b)) {
            return true;
        }

        if (a.length != b.length)
            return false;
        var step:Bool;
        for (i in 0...a.length) {
            step = item.equals(a[i], b[i]);
            if ( !step ) {
                return false;
            }
        }
        return true;
    }

    var item(default, null): Equator<T>;
}

class EnumValueEquator<T:EnumValue> extends BaseEquator<T> {
    var enumType(default, null): Enum<T>;
    public function new(e) {
        super();
        this.enumType = e;
    }
    override function equals(a:T, b:T):Bool {
        return super.equals(a, b) || a.equals(b);
    }
}

class NumericalEquator<T:Float> extends BaseEquator<T> {
    /* Constructor Function */
    public function new(?e: Float) {
        super();
        this.epsilon = e != null ? e : EPSILON;
    }

    override function equals(a:T, b:T):Bool {
        return almostEquals(a, b, epsilon);
    }

    static function almostEquals(a:Float, b:Float, ?epsilon:Float):Bool {
        if (epsilon == null) {
            return (a == b);
        }

        if (a == b) {
            return true;
        }

        if (Math.isNaN(a) || Math.isNaN(b)) {
            return false;
        }

        if (Math.isFinite(a) && Math.isFinite(b)) {
            var diff = Math.abs(a - b);
            if (diff < EPSILON) {
                return true;
            }
            else {
                return (diff <= Math.max(Math.abs(a), Math.abs(b)) * epsilon);
            }
        }

        return false;
    }

    var epsilon(default, null): Float;
    static inline var EPSILON:Float = 2.2204460492503130808472633361816e-16;
}

class MappedEquator<TIn, TOut> implements IEquator<TOut> {
    /* Constructor Function */
    public function new(eq:Equator<TIn>, map:TOut->TIn) {
        this.eq = eq;
        this.map = map;
    }

    public function equals(a:TOut, b:TOut):Bool {
        return (a == b || eq.equals(map(a), map(b)));
    }

    var eq(default, null): Equator<TIn>;
    var map(default, null): TOut->TIn;
}

class FEquator<T> extends BaseEquator<T> {
    var f(default, null): T->T->Bool;
    public function new(f) {
        super();
        this.f = f;
    }
    override function equals(a:T, b:T):Bool {
        return super.equals(a, b) || f(a, b);
    }
}

interface IEquator<T> {
    function equals(a:T, b:T):Bool;
}
