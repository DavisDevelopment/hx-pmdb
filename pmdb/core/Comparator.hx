package pmdb.core;

import tannus.io.ByteArray;
import tannus.ds.Dict;

import tannus.math.TMath as Math;

import haxe.io.Bytes;

import pmdb.ql.ts.DataType;
import pmdb.ql.ts.TypedData;
import pmdb.ql.ts.TypeChecks;
import pmdb.ql.ts.TypeCasts;
import pmdb.ql.ts.TypeSystemError;

import pmdb.ql.ts.TypeChecks.*;

using tannus.ds.SortingTools;
using tannus.FunctionTools;
using pmdb.ql.ts.DataTypes;

@:forward(compare)
abstract Comparator<T> (RootComparator<T>) from RootComparator<T> to RootComparator<T> {
/* === Instance Methods === */

    /* a < b */
    public inline function lt(a:T, b:T):Bool {
        return this.lt(a, b);
    }

    /* a <= b */
    public inline function lte(a:T, b:T):Bool {
        return this.lte(a, b);
    }

    /* a > b */
    public inline function gt(a:T, b:T):Bool {
        return this.gt(a, b);
    }

    /* a >= b */
    public inline function gte(a:T, b:T):Bool {
        return this.gte(a, b);
    }

    /* a == b */
    public inline function eq(a:T, b:T):Bool {
        return this.eq(a, b);
    }

    public function invert():Comparator<T> {
        if ((this is InvertedComparator<Dynamic>)) {
            return cast (@:privateAccess cast(this, InvertedComparator<Dynamic>).c);
        }
        else {
            return new InvertedComparator( this );
        }
    }

    /**
      create and return a Comparator for comparing arrays of the same value that [this] Comparator compares
     **/
    public inline function toArrayComparator():Comparator<Array<T>> {
        return arrayComparator(this);
    }

    /**
      make [this] Comparator nullable
     **/
    public inline function toNullable():Comparator<Null<T>> {
        return makeNullable( this );
    }

    /**
      'map' [this] Comparator
     **/
    public inline function map<O>(f: T->O):Comparator<O> {
        return cast new MappedComparator(cast this, f);
    }

/* === Static Instances === */

/* === Factories === */

    /**
      Boolean comparison
     **/
    @:noUsing public static inline function cboolean():Comparator<Bool> {
        return BooleanComparator.make();
    }

    /**
      Int comparison
     **/
    @:noUsing public static inline function cint():Comparator<Int> {
        return IntComparator.make();
    }

    /**
      Float comparison
     **/
    @:noUsing public static inline function cfloat():Comparator<Float> {
        return FloatComparator.make();
    }

    /**
      String comparison
     **/
    @:noUsing public static inline function cstring():Comparator<String> {
        return StringComparator.make();
    }

    /**
      ByteArray comparison
     **/
    @:noUsing public static inline function cbytes():Comparator<Bytes> {
        return BytesComparator.make(); 
    }

    /**
      Date comparison
     **/
    public static inline function cdate():Comparator<Date> return new DateComparator();

    /**
      Dynamic comparison
     **/
    public static inline function cany<T>():Comparator<T> return cast AnyComparator.make();

    public static inline function canon<T:{}>():Comparator<T> return cast AnonComparator.make();
    public static inline function cenum<T:EnumValue>():Comparator<T> return cast EnumValueComparator.make();
    
    /**
      <T> comparison
     **/
    @:from
    @:noUsing
    public static function create<T>(compare: T->T->Int):Comparator<T> {
        return new FComparator( compare );
    }

    /**
      Array<T> comparison
     **/
    @:noUsing
    public static function arrayComparator<T>(?itemComparator: Comparator<T>):Comparator<Array<T>> {
        if (itemComparator == null)
            return cast new ArrayComparator();
        else
            return new TypedArrayComparator( itemComparator );
    }

    @:noUsing
    public static function makeNullable<T>(c: Comparator<T>):Comparator<Null<T>> {
        return new NullableComparator( c );
    }
}

/**
  the interface which defines comparisons
 **/
interface IComparator<T> {
    function compare(a:T, b:T):Int;
    function eq(a:T, b:T):Bool;
    function lt(a:T, b:T):Bool;
    function lte(a:T, b:T):Bool;
    function gt(a:T, b:T):Bool;
    function gte(a:T, b:T):Bool;
}

private class RootComparator<T> implements IComparator<T> {
    function new() {
        this.cmp = function(x, y) {
            return -1;
        }
    }

    public function compare(a:T, b:T):Int {
        return cmp(a, b);
    }

    public function eq(a:T, b:T):Bool {
        if (equ != null)
            return equ(a, b);
        return (compare(a, b) == 0);
    }

    public function lt(a:T, b:T):Bool {
        return (compare(a, b) < 0);
    }

    public function lte(a:T, b:T):Bool {
        return (compare(a, b) <= 0);
    }

    public function gt(a:T, b:T):Bool {
        return (compare(a, b) > 0);
    }

    public function gte(a:T, b:T):Bool {
        return (compare(a, b) >= 0);
    }

    private var cmp:T->T->Int;
    private var equ:Null<T->T->Bool> = null;
}

class NumComparator<T:Float> extends RootComparator<T> {
    public function new() {
        super();
        cmp = (x:T, y:T) -> Arch.compareNumbers(x, y);
    }
}

class FloatComparator extends NumComparator<Float> {
    static var i:FloatComparator = new FloatComparator();
    public static inline function make():FloatComparator return i;
}

class IntComparator extends NumComparator<Int> {
    static var i:IntComparator = new IntComparator();
    public static inline function make():IntComparator return i;
}

class StringComparator extends RootComparator<String> {
    public function new() {
        super();
        cmp = (x:String, y:String) -> Arch.compareStrings(x, y);
    }

    static var i:StringComparator = new StringComparator();
    public static inline function make():StringComparator return i;
}

class BooleanComparator extends RootComparator<Bool> {
    public function new() {
        super();
        cmp = (x, y) -> Arch.compareBooleans(x, y);
    }

    static var i:BooleanComparator = new BooleanComparator();
    public static inline function make():BooleanComparator return i;
}

class DateComparator extends RootComparator<Date> {
    public function new() {
        super();
        cmp = (x, y) -> Arch.compareDates(x, y);
    }
}

class NullableComparator<T> extends RootComparator<Null<T>> {
    /* Constructor Function */
    public function new(c) {
        super();

        this.c = c;
        cmp = c.apply(rc -> (x, y) -> rc.compare(x, y));
        
        if (!is_instance(c, NullableComparator)) {
            cmp = cmp.wrap(function(_, x, y):Int {
                if (x == null) 
                    return (y == null) ? 0 : -1;
                else if (y == null)
                    return 1;
                else return _(x, y);
            });
        }
    }

    var c(default, null): Comparator<T>;
}

class TypedArrayComparator<T> extends RootComparator<Array<T>> {
    /* Constructor Function */
    public function new(c) {
        super();

        this.c = c;
        cmp = function(a:Array<T>, b:Array<T>):Int {
            return Arch.compareTypedArrays(a, b, (a, b) -> c.compare(a, b));
        }
    }

    var c(default, null): Comparator<T>;
}

class UntypedArrayComparator extends RootComparator<Array<Dynamic>> {
    /* Constructor Function */
    public function new() {
        super();
        cmp = (x, y) -> Arch.compareArrays(x, y);
    }
}
typedef ArrayComparator = UntypedArrayComparator;

class BytesComparator extends RootComparator<Bytes> {
    public function new() {
        super();

        cmp = (a, b) -> Arch.compareBytes(a, b);
    }

    private static var i(default, null): BytesComparator = new BytesComparator();
    public static function make():BytesComparator return i;
}

class AnonComparator<T:{}> extends FComparator<T> {
    public function new() {
        super((x, y) -> Arch.compareObjects(x, y));
    }

    static var i = new AnonComparator<{}>();
    public static inline function make<T:{}>():T return cast i;
}

class EnumValueComparator<T:EnumValue> extends FComparator<T> {
    public function new() {
        super((x, y) -> Arch.compareEnumValues(x, y));
    }

    static var i:EnumValueComparator<EnumValue> = new EnumValueComparator();
    public static inline function make<T:EnumValue>():T return cast i;
}

class AnyComparator<T> extends RootComparator<T> {
    /* Constructor Function */
    public function new() {
        super();

        cmp = (x:T, y:T) -> Arch.compareThings(x, y);
    }

/* === Fields === */

    static var i:AnyComparator<Any> = new AnyComparator();
    public static inline function make():AnyComparator<Any> return i;
}

class MappedComparator<TFrom, TTo> extends RootComparator<TFrom> {
    /* Constructor Function */
    public function new(c, f) {
        super();
        this.c = c;
        value = f;
        this.cmp = (x, y) -> c.compare(value(x), value(y));
    }

    var c(default, null): Comparator<TTo>;
    var value(default, null): TFrom -> TTo;
}

class FComparator<T> extends RootComparator<T> {
    /* Constructor Function */
    public function new(f) {
        super();
        cmp = (x, y) -> f(x, y);
    }
}

class InvertedComparator<T> extends RootComparator<T> {
    /* Constructor Function */
    public function new(c) {
        super();

        this.c = c;
        cmp = (x:T, y:T) -> -c.compare(x, y);
    }
    var c(default, null): Comparator<T>;
}
