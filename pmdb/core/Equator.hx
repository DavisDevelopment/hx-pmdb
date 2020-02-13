package pmdb.core;

//import tannus.math.TMath as Math;

import pmdb.core.Object;
import pmdb.core.Comparator;

import haxe.io.Bytes;
import haxe.io.*;

using pm.Arrays;
using pm.Functions;

@:forward
abstract Equator<T> (BaseEquator<T>) from BaseEquator<T> {
/* === Instance Methods === */

    public inline function map<Out>(f: Out -> T):Equator<Out> {
        return new MappedEquator<T, Out>(this, f);
    }

/* === Factory Methods === */

    @:from @:noUsing
    public static function create<T>(feq: T->T->Bool):Equator<T> {
        return new FEquator( feq );
    }

    public static function anyEq<T>():Equator<T> { return new AnyEquator(); }
    public static function boolEq():Equator<Bool> { return new BoolEquator(); }
    public static function floatEq():Equator<Float> return new FloatEquator();
    public static function intEq():Equator<Int> return new IntEquator();
    public static function stringEq():Equator<String> return new StringEquator();
    public static function bytesEq():Equator<Bytes> return new BytesEquator();
    public static function dateEq():Equator<Date> return new DateEquator();

    @:noUsing @:from
    public static function typedArrayEquator<T>(e: Equator<T>):Equator<Array<T>> {
        return new TypedArrayEquator( e );
    }

    @:noUsing @:from
    public static function funcTypedArrayEquator<T>(fn: T -> T -> Bool):Equator<Array<T>> {
        return new FTypedArrayEquator( fn );
    }

    public static function structEq<T:{}>():Equator<T> {
        return new StructEquator<T>();
    }

    @:noUsing
    public static function enumValueEq<E:EnumValue>(e: Enum<E>):Equator<E> { return new EnumValueEquator( e ); }
}

class BaseEquator<T> {
    /* Constructor Function */
    public function new() {
        neq = null;
        eq = function(a:T, b:T):Bool {
            return (a == b);
        }
    }

/* === Methods === */

    public inline function equals(a:T, b:T):Bool {
        return eq(a, b);
    }

    public function nequals(a:T, b:T):Bool {
        return neq == null ? !equals(a, b) : neq(a, b);
    }

/* === Fields === */

    private var eq:T -> T -> Bool;
    private var neq:Null<T -> T -> Bool>;
}

class FEquator<T> extends BaseEquator<T> {
    public function new(fn) {
        super();
        eq = fn;
    }
}

class BoolEquator extends FEquator<Bool> {
    public function new() {
        super((a:Bool, b:Bool) -> Arch.boolEquality(a, b));
    }
}

class StringEquator extends FEquator<String> {
    public function new() {
        super((a:String, b:String) -> Arch.stringEquality(a, b));
    }
}

class BytesEquator extends FEquator<Bytes> {
    public function new() {
        super((a:Bytes, b:Bytes) -> Arch.bytesEquality(a, b));
    }
}

class DateEquator extends FEquator<Date> {
    public function new() {
        super((a:Date, b:Date) -> Arch.dateEquality(a, b));
    }
}

class TypedArrayEquator<T> extends DerivedEquator<T, Array<T>> {
    public function new(eeq: Equator<T>) {
        super(eeq);

        this.eq = (x, y) -> Arch.typedArrayEquality(x, y, (x, y) -> from.equals(x, y));
    }
}

class FTypedArrayEquator<T> extends TypedArrayEquator<T> {
    public function new(fn: T -> T -> Bool) {
        super(new FEquator<T>( fn ));
    }
}

class ArrayEquator<T> extends BaseEquator<Array<T>> {
    public function new() {
        super();
        eq = (x, y) -> Arch.arrayEquality(x, y);
    }
}

class EnumValueEquator<T:EnumValue> extends BaseEquator<T> {
    public function new(e: Enum<T>) {
        super();

        enumType = e;
        eq = function(a:T, b:T):Bool {
            return (
                Type.getEnum(a) == enumType &&
                Type.getEnum(b) == enumType &&
                Arch.enumValueEquality(a, b)
            );
        }
    }

    private var enumType(default, null): Enum<T>;
}

#if java @:generic #end
class NumericalEquator<T:Float> extends BaseEquator<T> {
    /* Constructor Function */
    public function new(e: Bool = false) {
        super();

        useEpsilon = e;
        eq = function(a:T, b:T):Bool {
            return N.almostEquals(a, b, useEpsilon);
        }
    }

	private var useEpsilon(default, null):Bool;
}
private class N {
	/**
		algorithm for determining approximate equality between two floating-point numbers
		[=NOTE=] approximate equality is useful because of the loss of precision in floats past certain platform-specific values
    **/
    public static function almostEquals(a:Float, b:Float, useEpsilon:Bool = false):Bool {
		if (!useEpsilon) {
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
			} else {
				return (diff <= Math.max(Math.abs(a), Math.abs(b)) * EPSILON);
			}
		}

		return false;
    }

	
	static inline var EPSILON:Float = 2.2204460492503130808472633361816e-16;
}

// class IntEquator extends FEquator<Int> {
//     public function new() {
//         super((x, y) -> Arch.intEquality(x, y));
//     }
// }
class IntEquator extends BaseEquator<Int> {
    static function int_equality(a:Int, b:Int):Bool {
        return a == b || Arch.intEquality(a, b);
    }

    public function new() {
        super();
        this.eq = int_equality;
    }
}

class FloatEquator extends NumericalEquator<Float> {
    public function new() {
        super(true);
    }
}

class StructEquator<T:{}> extends FEquator<T> {
    public function new() {
        super((a:T, b:T) -> Arch.objectEquality(cast a, cast b));
    }
}

class DerivedEquator<TFrom, T> extends BaseEquator<T> {
    private var from(default, null): Equator<TFrom>;
    /* Constructor Function */
    public function new(e: Equator<TFrom>):Void {
        super();

        from = e;
    }
}

class MappedEquator<A, B> extends DerivedEquator<A, B> {
    /* Constructor Function */
    public function new(eq:Equator<A>, map:B -> A):Void {
        super( eq );

        this.map = map;
        this.eq = function(a:B, b:B):Bool {
            return from.equals(map(a), map(b));
        }
        this.neq = function(a:B, b:B):Bool {
            return from.nequals(map(a), map(b));
        }
    }

    var map(default, null): B -> A;
}

/**
  Equator for testing equality between any two values of any two types
  [=NOTE=] I'm actually not quite sure why this class takes a type parameter; I just put it there because it feels right
 **/
class AnyEquator<T> extends BaseEquator<T> {
    public function new() {
        super();
        eq = (x:T, y:T) -> Arch.areThingsEqual(x, y);
    }
}
